from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy import Column, String, Integer, DateTime, Boolean, Text, Float, JSON, ForeignKey
from app.core.config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

def get_utc_now():
    return datetime.now(timezone.utc).replace(tzinfo=None)

class User(Base):
    __tablename__ = "users"
    
    id = Column(String(36), primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=get_utc_now)

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(String(36), primary_key=True, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), index=True, nullable=False)
    original_name = Column(String(255), nullable=False)
    encrypted_filename = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    mime_type = Column(String(100), nullable=False)
    content_hash = Column(String(64), index=True, nullable=True)  # SHA-256 for deduplication
    category = Column(String(50), default="General", index=True)
    sensitivity = Column(String(20), default="LOW", index=True)
    pii_summary = Column(JSON, default=dict)
    summary_preview = Column(Text, nullable=True)
    created_at = Column(DateTime, default=get_utc_now)

class ShareLink(Base):
    __tablename__ = "share_links"
    
    id = Column(String(36), primary_key=True, index=True)
    doc_id = Column(String(36), ForeignKey("documents.id"), index=True, nullable=False)
    user_id = Column(String(36), ForeignKey("users.id"), index=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)
    max_downloads = Column(Integer, default=1)
    download_count = Column(Integer, default=0)
    expires_at = Column(DateTime, nullable=False)
    is_revoked = Column(Boolean, default=False)
    created_at = Column(DateTime, default=get_utc_now)

class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(36), ForeignKey("users.id"), index=True, nullable=False)
    action = Column(String(100), nullable=False)  # LOGIN, UPLOAD, DECRYPT, SEARCH, EXPORT
    ip_address = Column(String(45), default="127.0.0.1")
    risk_score = Column(Integer, default=0)
    is_anomaly = Column(Boolean, default=False)
    details = Column(JSON, default=dict)
    timestamp = Column(DateTime, default=get_utc_now)

class AnomalyAlert(Base):
    __tablename__ = "anomaly_alerts"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(36), ForeignKey("users.id"), index=True, nullable=False)
    severity = Column(String(20), default="WARNING")  # LOW, ELEVATED, CRITICAL
    risk_score = Column(Integer, nullable=False)
    reasons = Column(JSON, default=list)
    is_resolved = Column(Boolean, default=False)
    timestamp = Column(DateTime, default=get_utc_now)

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
