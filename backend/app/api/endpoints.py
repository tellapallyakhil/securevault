import uuid
import io
from pathlib import Path
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Header
from fastapi.responses import StreamingResponse
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.config import settings
from app.core.security import verify_password, get_password_hash, create_access_token
from app.models.models import get_db, User, Document, AuditLog, AnomalyAlert, ShareLink
from app.schemas.schemas import (
    UserRegister, UserLogin, TokenResponse, DocumentOut,
    SearchQuery, SearchResultOut, AnomalyAssessmentOut, SecurityStatsOut,
    ShareLinkCreate, ShareLinkOut
)
from app.services.crypto_service import crypto_service
from app.services.ocr_service import ocr_service
from app.services.pii_service import pii_service
from app.services.search_service import search_service
from app.services.anomaly_service import anomaly_service

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if user is None:
        raise credentials_exception
    return user

# ================= AUTHENTICATION ================= #

@router.post("/auth/register", response_model=TokenResponse)
async def register(user_in: UserRegister, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == user_in.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="User with this email already exists.")
        
    user_id = str(uuid.uuid4())
    user = User(
        id=user_id,
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.full_name or user_in.email.split("@")[0]
    )
    db.add(user)
    await db.commit()
    
    access_token = create_access_token(subject=user.id)
    return TokenResponse(
        access_token=access_token,
        user_id=user.id,
        full_name=user.full_name,
        email=user.email
    )

@router.post("/auth/login", response_model=TokenResponse)
async def login(credentials: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == credentials.email))
    user = result.scalars().first()
    
    # Behavioral telemetry check for Isolation Forest
    now = datetime.now(timezone.utc)
    telemetry = {
        "hour": now.hour + now.minute / 60.0,
        "access_frequency": 2.0,
        "ip_changed": credentials.client_ip != "127.0.0.1",
        "failed_attempts": 0 if (user and verify_password(credentials.password, user.hashed_password)) else 3,
        "high_sens_count": 0
    }
    
    assessment = anomaly_service.assess_risk(telemetry)
    
    if not user or not verify_password(credentials.password, user.hashed_password):
        # Log failed attempt
        if user:
            db.add(AuditLog(
                user_id=user.id,
                action="LOGIN_FAILED",
                ip_address=credentials.client_ip,
                risk_score=assessment["risk_score"],
                is_anomaly=True,
                details={"reason": "Invalid credentials", "assessment": assessment}
            ))
            await db.commit()
        raise HTTPException(status_code=401, detail="Invalid email or password")
        
    # Log successful login with anomaly assessment
    audit = AuditLog(
        user_id=user.id,
        action="LOGIN_SUCCESS",
        ip_address=credentials.client_ip,
        risk_score=assessment["risk_score"],
        is_anomaly=assessment["is_anomaly"],
        details={"device_id": credentials.device_id, "assessment": assessment}
    )
    db.add(audit)
    
    if assessment["is_anomaly"]:
        alert = AnomalyAlert(
            user_id=user.id,
            severity=assessment["risk_level"],
            risk_score=assessment["risk_score"],
            reasons=assessment["reasons"]
        )
        db.add(alert)
        
    await db.commit()
    
    access_token = create_access_token(subject=user.id)
    return TokenResponse(
        access_token=access_token,
        user_id=user.id,
        full_name=user.full_name,
        email=user.email
    )

@router.get("/auth/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "created_at": current_user.created_at.isoformat()
    }

# ================= DOCUMENT MANAGEMENT ================= #

@router.post("/documents/upload", response_model=DocumentOut)
async def upload_document(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    # Deduplication check via SHA-256 Content-Addressable Storage
    import hashlib
    content_hash = hashlib.sha256(content).hexdigest()
    dup_res = await db.execute(
        select(Document).where(Document.user_id == current_user.id, Document.content_hash == content_hash)
    )
    existing = dup_res.scalars().first()
    if existing:
        # Deduplication hit: Save disk space and return existing record
        existing.is_duplicate = True
        return existing

    # Step 1: Text extraction via OCR
    extracted_text = ocr_service.extract_text_from_bytes(content, file.filename)
    
    # Step 2: Sensitive PII Detection & Categorization
    pii_analysis = pii_service.analyze_text(extracted_text)
    
    # Step 3: Strong AES-256-GCM Encryption
    encrypted_bytes = crypto_service.encrypt_bytes(content)
    
    doc_id = str(uuid.uuid4())
    stored_filename = f"{doc_id}.enc"
    encrypted_filepath = settings.VAULT_DIR / stored_filename
    
    with open(encrypted_filepath, "wb") as f:
        f.write(encrypted_bytes)

    # Step 4: Add to FAISS Vector Search Index
    search_service.add_document(
        doc_id=doc_id,
        text=extracted_text,
        metadata={
            "original_name": file.filename,
            "category": pii_analysis["category"],
            "sensitivity": pii_analysis["sensitivity"],
            "user_id": current_user.id
        }
    )

    # Step 5: Save metadata record in DB
    db_doc = Document(
        id=doc_id,
        user_id=current_user.id,
        original_name=file.filename,
        encrypted_filename=stored_filename,
        file_size=len(content),
        mime_type=file.content_type or "application/octet-stream",
        content_hash=content_hash,
        category=pii_analysis["category"],
        sensitivity=pii_analysis["sensitivity"],
        pii_summary=pii_analysis,
        summary_preview=extracted_text[:200] if extracted_text else ""
    )
    db.add(db_doc)
    
    # Audit log
    db.add(AuditLog(
        user_id=current_user.id,
        action="DOCUMENT_UPLOAD",
        risk_score=15 if pii_analysis["sensitivity"] == "HIGH" else 5,
        is_anomaly=False,
        details={"doc_id": doc_id, "filename": file.filename, "sensitivity": pii_analysis["sensitivity"]}
    ))
    await db.commit()
    await db.refresh(db_doc)
    
    return db_doc

@router.get("/documents/", response_model=List[DocumentOut])
async def list_documents(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Document).where(Document.user_id == current_user.id).order_by(Document.created_at.desc())
    )
    return result.scalars().all()

@router.get("/documents/{doc_id}/download")
async def download_document(
    doc_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Document).where(Document.id == doc_id, Document.user_id == current_user.id)
    )
    doc = result.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
        
    file_path = settings.VAULT_DIR / doc.encrypted_filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Encrypted file not found on disk")
        
    with open(file_path, "rb") as f:
        encrypted_bytes = f.read()
        
    # Decrypt AES-256-GCM payload with integrity verification
    try:
        decrypted_bytes = crypto_service.decrypt_bytes(encrypted_bytes)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Decryption failed: integrity compromised! ({str(e)})")
        
    # Audit log access
    db.add(AuditLog(
        user_id=current_user.id,
        action="DOCUMENT_DECRYPT_DOWNLOAD",
        risk_score=10,
        is_anomaly=False,
        details={"doc_id": doc.id, "filename": doc.original_name}
    ))
    await db.commit()
    
    return StreamingResponse(
        io.BytesIO(decrypted_bytes),
        media_type=doc.mime_type,
        headers={"Content-Disposition": f'attachment; filename="{doc.original_name}"'}
    )

@router.get("/documents/{doc_id}/redacted")
async def get_redacted_preview(
    doc_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the PII-redacted preview of the document.
    Replaces sensitive IDs (Aadhaar, PAN, SSN, Credit Cards) with secure redaction masks.
    """
    result = await db.execute(
        select(Document).where(Document.id == doc_id, Document.user_id == current_user.id)
    )
    doc = result.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
        
    file_path = settings.VAULT_DIR / doc.encrypted_filename
    with open(file_path, "rb") as f:
        encrypted_bytes = f.read()
    
    decrypted_bytes = crypto_service.decrypt_bytes(encrypted_bytes)
    raw_text = ocr_service.extract_text_from_bytes(decrypted_bytes, doc.original_name)
    redacted_text = pii_service.redact_text(raw_text)

    return {
        "doc_id": doc.id,
        "original_name": doc.original_name,
        "category": doc.category,
        "sensitivity": doc.sensitivity,
        "pii_summary": doc.pii_summary,
        "redacted_text": redacted_text,
        "total_pii_masked": doc.pii_summary.get("total_pii_count", 0)
    }

@router.post("/documents/{doc_id}/share", response_model=ShareLinkOut)
async def create_share_link(
    doc_id: str,
    share_in: ShareLinkCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Generates a secure, time-limited, password-protected sharing link.
    """
    result = await db.execute(
        select(Document).where(Document.id == doc_id, Document.user_id == current_user.id)
    )
    doc = result.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    share_id = str(uuid.uuid4())
    from datetime import timedelta
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    expires_at = now_utc + timedelta(hours=share_in.expires_in_hours or 24)

    share_link = ShareLink(
        id=share_id,
        doc_id=doc.id,
        user_id=current_user.id,
        hashed_password=get_password_hash(share_in.password) if share_in.password else None,
        max_downloads=share_in.max_downloads or 1,
        download_count=0,
        expires_at=expires_at,
        created_at=now_utc
    )
    db.add(share_link)
    
    # Audit log share creation
    db.add(AuditLog(
        user_id=current_user.id,
        action="SHARE_LINK_CREATED",
        risk_score=20 if doc.sensitivity == "HIGH" else 10,
        is_anomaly=False,
        details={"doc_id": doc.id, "share_id": share_id, "expires_at": expires_at.isoformat()}
    ))
    await db.commit()

    return ShareLinkOut(
        share_id=share_id,
        share_url=f"http://localhost:8000{settings.API_V1_STR}/share/{share_id}",
        doc_id=doc.id,
        original_name=doc.original_name,
        expires_at=expires_at,
        max_downloads=share_link.max_downloads,
        requires_password=share_in.password is not None
    )

@router.get("/share/{share_id}")
async def access_shared_document(
    share_id: str,
    password: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Public recipient download endpoint with expiration and password verification.
    """
    result = await db.execute(select(ShareLink).where(ShareLink.id == share_id))
    link = result.scalars().first()
    if not link or link.is_revoked:
        raise HTTPException(status_code=404, detail="Share link not found or revoked.")

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    if now_utc > link.expires_at:
        raise HTTPException(status_code=410, detail="This secure share link has expired.")

    if link.download_count >= link.max_downloads:
        raise HTTPException(status_code=410, detail="Maximum download limit reached. Link burned.")

    if link.hashed_password:
        if not password or not verify_password(password, link.hashed_password):
            raise HTTPException(status_code=401, detail="Password required or incorrect for this shared link.")

    doc_res = await db.execute(select(Document).where(Document.id == link.doc_id))
    doc = doc_res.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document no longer exists.")

    file_path = settings.VAULT_DIR / doc.encrypted_filename
    with open(file_path, "rb") as f:
        encrypted_bytes = f.read()

    decrypted_bytes = crypto_service.decrypt_bytes(encrypted_bytes)
    
    # Increment download count
    link.download_count += 1
    await db.commit()

    return StreamingResponse(
        io.BytesIO(decrypted_bytes),
        media_type=doc.mime_type,
        headers={"Content-Disposition": f'attachment; filename="{doc.original_name}"'}
    )

# ================= SEMANTIC SEARCH ================= #

@router.post("/documents/search", response_model=List[SearchResultOut])
async def search_vault(
    query_in: SearchQuery,
    current_user: User = Depends(get_current_user)
):
    results = search_service.search(
        query=query_in.query,
        top_k=query_in.top_k or 5,
        user_id=current_user.id
    )
    output = []
    for r in results:
        meta = r.get("metadata", {})
        score = r["score"]
        conf_pct = min(100, int(score * 120))  # normalize score visualization
        preview = meta.get("text_preview") or ""
        snippet = f"Match confidence: {conf_pct}%"
        if preview and not preview.startswith("[Extracted") and not preview.startswith("[PDF"):
            clean_snippet = preview.replace("\n", " ").strip()
            if len(clean_snippet) > 80:
                clean_snippet = clean_snippet[:80] + "..."
            snippet = f"{snippet} • {clean_snippet}"
            
        output.append(SearchResultOut(
            doc_id=r["doc_id"],
            score=round(score, 4),
            original_name=meta.get("original_name") or meta.get("name", "Unknown"),
            category=meta.get("category", "General"),
            sensitivity=meta.get("sensitivity", "LOW"),
            snippet=snippet
        ))
    return output

@router.post("/documents/sync-index")
async def sync_vector_index(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Document))
    documents = result.scalars().all()
    doc_dicts = [
        {
            "id": str(d.id),
            "user_id": str(d.user_id),
            "original_name": d.original_name,
            "category": d.category,
            "sensitivity": d.sensitivity,
            "summary_preview": d.summary_preview or "",
            "file_size": d.file_size,
            "created_at": d.created_at.isoformat() if d.created_at else ""
        }
        for d in documents
    ]
    search_service.sync_documents(doc_dicts)
    return {"status": "success", "indexed_documents": len(doc_dicts)}

# ================= SECURITY CENTER & ANOMALY TELEMETRY ================= #

@router.get("/security/status", response_model=SecurityStatsOut)
async def get_security_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Total documents
    doc_res = await db.execute(select(Document).where(Document.user_id == current_user.id))
    docs = doc_res.scalars().all()
    total_docs = len(docs)
    high_sens = sum(1 for d in docs if d.sensitivity == "HIGH")
    
    # Recent alerts
    alert_res = await db.execute(
        select(AnomalyAlert)
        .where(AnomalyAlert.user_id == current_user.id)
        .order_by(AnomalyAlert.timestamp.desc())
        .limit(5)
    )
    alerts = alert_res.scalars().all()
    
    latest_risk = alerts[0].risk_score if alerts else 8
    threat_level = "ELEVATED" if latest_risk > 60 else ("WARNING" if latest_risk > 30 else "OPTIMAL")

    return SecurityStatsOut(
        total_documents=total_docs,
        high_sensitivity_count=high_sens,
        active_threat_level=threat_level,
        latest_anomaly_score=latest_risk,
        recent_alerts=[
            {
                "id": a.id,
                "severity": a.severity,
                "score": a.risk_score,
                "reasons": a.reasons,
                "timestamp": a.timestamp.isoformat()
            }
            for a in alerts
        ]
    )

@router.post("/security/telemetry", response_model=AnomalyAssessmentOut)
async def evaluate_telemetry(
    data: dict,
    current_user: User = Depends(get_current_user)
):
    assessment = anomaly_service.assess_risk(data)
    return AnomalyAssessmentOut(
        is_anomaly=assessment["is_anomaly"],
        anomaly_score=assessment["anomaly_score"],
        risk_score=assessment["risk_score"],
        risk_level=assessment["risk_level"],
        reasons=assessment["reasons"],
        timestamp=assessment["timestamp"]
    )
