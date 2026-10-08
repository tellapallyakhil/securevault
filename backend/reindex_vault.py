import asyncio
import os
import sys
from pathlib import Path

# Add backend directory to path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from sqlalchemy.future import select
from app.models.models import AsyncSessionLocal, Document
from app.services.search_service import search_service

async def reindex_vault():
    print("=" * 60)
    print("SECUREVAULT AI - VECTOR SEARCH RE-INDEXING & SYNC UTILITY")
    print("Model: sentence-transformers/all-MiniLM-L6-v2 (384-dim Dense BERT)")
    print("Vector Store: FAISS IndexFlatIP (Cosine Similarity)")
    print("=" * 60)

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Document))
        documents = result.scalars().all()
        print(f"Discovered {len(documents)} document(s) in database.")

        doc_dicts = []
        for d in documents:
            doc_dicts.append({
                "id": str(d.id),
                "user_id": str(d.user_id),
                "original_name": d.original_name,
                "category": d.category,
                "sensitivity": d.sensitivity,
                "summary_preview": d.summary_preview or "",
                "file_size": d.file_size,
                "created_at": d.created_at.isoformat() if d.created_at else ""
            })
            print(f" - [{d.category:10s}] {d.original_name} (User: {d.user_id[:8]}...)")

        search_service.sync_documents(doc_dicts)
        print("Vector index synchronization complete!")
        print("=" * 60)

if __name__ == "__main__":
    asyncio.run(reindex_vault())
