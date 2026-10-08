from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str
    client_ip: Optional[str] = "127.0.0.1"
    device_id: Optional[str] = "unknown-device"

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    full_name: Optional[str]
    email: str

class DocumentOut(BaseModel):
    id: str
    original_name: str
    file_size: int
    mime_type: str
    category: str
    sensitivity: str
    pii_summary: Dict[str, Any]
    summary_preview: Optional[str] = None
    is_duplicate: Optional[bool] = False
    created_at: datetime

    class Config:
        from_attributes = True

class ShareLinkCreate(BaseModel):
    expires_in_hours: Optional[int] = 24
    password: Optional[str] = None
    max_downloads: Optional[int] = 1

class ShareLinkOut(BaseModel):
    share_id: str
    share_url: str
    doc_id: str
    original_name: str
    expires_at: datetime
    max_downloads: int
    requires_password: bool

class SearchQuery(BaseModel):
    query: str
    top_k: Optional[int] = 5

class SearchResultOut(BaseModel):
    doc_id: str
    score: float
    original_name: str
    category: str
    sensitivity: str
    snippet: Optional[str] = None

class AnomalyAssessmentOut(BaseModel):
    is_anomaly: bool
    anomaly_score: float
    risk_score: int
    risk_level: str
    reasons: List[str]
    timestamp: str

class SecurityStatsOut(BaseModel):
    total_documents: int
    high_sensitivity_count: int
    active_threat_level: str
    latest_anomaly_score: int
    recent_alerts: List[Dict[str, Any]]
