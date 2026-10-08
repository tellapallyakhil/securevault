import requests
import uuid
import json
from datetime import datetime

SUPABASE_URL = "https://jujqnwewcznqqwtrazbx.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1anFud2V3Y3pucXF3dHJhemJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4MjYyMTUsImV4cCI6MjEwNTQwMjIxNX0.Lrr6o9x7yAGEpPMvh7HXm9GsEJUuB295GqS7zHSTleI"

HEADERS = {
    "apikey": SUPABASE_ANON_KEY,
    "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def test_supabase_http():
    print("=" * 60)
    print("SECUREVAULT AI — LIVE POSTGREST HTTPS API VERIFICATION")
    print("(Matching exact protocol used by Flutter supabase_flutter client)")
    print("=" * 60)

    # 1. Test Users Table
    test_user_id = str(uuid.uuid4())
    test_email = f"test_{int(datetime.now().timestamp())}@securevault.ai"

    user_payload = {
        "id": test_user_id,
        "email": test_email,
        "hashed_password": "test_hash_password_123",
        "full_name": "PostgREST Verification User",
        "is_active": True,
        "created_at": datetime.now().isoformat()
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/users", headers=HEADERS, json=user_payload)
    assert r.status_code in [200, 201], f"User insert failed: {r.status_code} - {r.text}"
    print(f"[1/5] Users Table (HTTPS): Created test user {test_email} (HTTP {r.status_code})")

    # 2. Test user_biometrics Table
    bio_payload = {
        "user_id": test_user_id,
        "fingerprint_enrolled": True,
        "facelock_enrolled": True,
        "face_template_hash": "FACE_LANDMARKS_0.81,0.36,0.39,0.64",
        "face_landmarks_data": "[0.81, 0.36, 0.39, 0.64, 0.41, 0.51]",
        "dual_biometric_required": True,
        "updated_at": datetime.now().isoformat()
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/user_biometrics", headers=HEADERS, json=bio_payload)
    assert r.status_code in [200, 201], f"Biometrics insert failed: {r.status_code} - {r.text}"
    
    # Query back biometrics
    r = requests.get(f"{SUPABASE_URL}/rest/v1/user_biometrics?user_id=eq.{test_user_id}", headers=HEADERS)
    assert r.status_code == 200
    bio_data = r.json()
    assert len(bio_data) > 0
    assert bio_data[0]["fingerprint_enrolled"] is True
    assert bio_data[0]["facelock_enrolled"] is True
    assert bio_data[0]["dual_biometric_required"] is True
    print(f"[2/5] Biometrics Table (HTTPS): Cloud sync verified! Fingerprint=True, FaceLock=True, Dual=True")

    # 3. Test documents Table (Local file metadata with Aadhaar/PAN classification)
    test_doc_id = str(uuid.uuid4())
    doc_payload = {
        "id": test_doc_id,
        "user_id": test_user_id,
        "original_name": "Aadhaar_Card_Verified.jpg",
        "encrypted_filename": f"{test_doc_id}_Aadhaar_Card_Verified.jpg",
        "file_size": 245000,
        "mime_type": "image/jpeg",
        "content_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "category": "Identity",
        "sensitivity": "HIGH",
        "pii_summary": {
            "document_type": "Aadhaar Card",
            "sensitivity": "HIGH",
            "counts_by_type": {"AADHAAR": 1},
            "ocr_char_count": 142
        },
        "summary_preview": "[Aadhaar Card] Encrypted on-device (AES-256-GCM). SHA-256 seal: e3b0c442...",
        "created_at": datetime.now().isoformat()
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/documents", headers=HEADERS, json=doc_payload)
    assert r.status_code in [200, 201], f"Document insert failed: {r.status_code} - {r.text}"
    
    # Query back document
    r = requests.get(f"{SUPABASE_URL}/rest/v1/documents?id=eq.{test_doc_id}", headers=HEADERS)
    doc_data = r.json()
    assert len(doc_data) > 0
    assert doc_data[0]["category"] == "Identity"
    assert doc_data[0]["sensitivity"] == "HIGH"
    assert doc_data[0]["pii_summary"]["document_type"] == "Aadhaar Card"
    print(f"[3/5] Documents Table (HTTPS): Metadata stored! Category=Identity, Type=Aadhaar Card, Sensitivity=HIGH")

    # 4. Test anomaly_alerts Table
    alert_payload = {
        "user_id": test_user_id,
        "severity": "CRITICAL",
        "risk_score": 88,
        "reasons": ["Abnormal off-hours burst request velocity", "Unrecognized IP address"],
        "is_resolved": False,
        "timestamp": datetime.now().isoformat()
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/anomaly_alerts", headers=HEADERS, json=alert_payload)
    assert r.status_code in [200, 201], f"Anomaly alert insert failed: {r.status_code} - {r.text}"
    alert_created = r.json()[0]
    alert_id = alert_created["id"]

    # Resolve alert
    r = requests.patch(
        f"{SUPABASE_URL}/rest/v1/anomaly_alerts?id=eq.{alert_id}",
        headers=HEADERS,
        json={"is_resolved": True}
    )
    assert r.status_code == 200, f"Anomaly alert update failed: {r.status_code} - {r.text}"
    print(f"[4/5] Anomaly Alerts Table (HTTPS): Real-time alert inserted & marked resolved!")

    # 5. Test audit_logs Table
    audit_payload = {
        "user_id": test_user_id,
        "action": "UPLOAD_LOCAL_VAULT",
        "ip_address": "127.0.0.1",
        "risk_score": 0,
        "is_anomaly": False,
        "details": {
            "filename": "Aadhaar_Card_Verified.jpg",
            "storage": "device_local_storage_only",
            "document_type": "Aadhaar Card"
        },
        "timestamp": datetime.now().isoformat()
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/audit_logs", headers=HEADERS, json=audit_payload)
    assert r.status_code in [200, 201], f"Audit log insert failed: {r.status_code} - {r.text}"
    print(f"[5/5] Audit Logs Table (HTTPS): Verified local-vault upload event audit trail!")

    # Cleanup
    requests.delete(f"{SUPABASE_URL}/rest/v1/documents?user_id=eq.{test_user_id}", headers=HEADERS)
    requests.delete(f"{SUPABASE_URL}/rest/v1/user_biometrics?user_id=eq.{test_user_id}", headers=HEADERS)
    requests.delete(f"{SUPABASE_URL}/rest/v1/anomaly_alerts?user_id=eq.{test_user_id}", headers=HEADERS)
    requests.delete(f"{SUPABASE_URL}/rest/v1/audit_logs?user_id=eq.{test_user_id}", headers=HEADERS)
    requests.delete(f"{SUPABASE_URL}/rest/v1/users?id=eq.{test_user_id}", headers=HEADERS)
    print("\nCleanup completed: Test records removed.")
    print("=" * 60)
    print("ALL 5/5 SUPABASE CLOUD REST API VERIFICATIONS PASSED 100%!")
    print("=" * 60)

if __name__ == "__main__":
    test_supabase_http()
