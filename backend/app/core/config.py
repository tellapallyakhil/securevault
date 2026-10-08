import os
from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "SecureVault AI Backend"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Security & JWT
    SECRET_KEY: str = "securevault-ultra-secret-encryption-master-key-2026-xyz-987"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day
    
    # Storage paths
    VAULT_DIR: Path = BASE_DIR / "vault_storage"
    DB_PATH: Path = BASE_DIR / "securevault.db"
    DATABASE_URL: str = f"sqlite+aiosqlite:///{DB_PATH}"
    
    # AI models
    EMBEDDING_MODEL: str = "all-MiniLM-L6-v2"
    FAISS_INDEX_DIR: Path = BASE_DIR / "faiss_index"
    
    # Anomaly Detection threshold
    ANOMALY_CONTAMINATION: float = 0.05
    
    # Gemini AI Integration
    GEMINI_API_KEY: str = ""
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()

# Ensure storage directories exist
settings.VAULT_DIR.mkdir(parents=True, exist_ok=True)
settings.FAISS_INDEX_DIR.mkdir(parents=True, exist_ok=True)
