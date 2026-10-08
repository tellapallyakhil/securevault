from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import settings
from app.models.models import init_db
from app.api.endpoints import router as api_router

from app.services.search_service import search_service

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize database
    await init_db()
    print("Database tables initialized successfully.")
    # Initialize FAISS + Sentence-BERT Vector Search
    search_service.lazy_load()
    yield
    # Shutdown

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="SecureVault AI: Encrypted Personal Data Management with Isolation Forest Behavioral Security",
    lifespan=lifespan
)

# Enable CORS for Flutter mobile/web/desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "SecureVault AI Enterprise Backend",
        "version": settings.VERSION,
        "features": {
            "encryption": "AES-256-GCM + Argon2id",
            "document_intelligence": "Tesseract OCR + Presidio PII Detection",
            "semantic_discovery": "Sentence Transformers + FAISS Vector Index",
            "behavioral_security": "Isolation Forest Anomaly Model"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
