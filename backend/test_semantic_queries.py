import sys
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from app.services.search_service import search_service

queries = [
    "my curriculum vitae and cv",
    "hospital prescription for heart checkup",
    "cloud server payment invoice",
    "photos taken from phone camera"
]

print("--- RUNNING HYBRID BERT SEMANTIC SEARCH TEST ---")
for q in queries:
    print(f"\n>>> Query: '{q}'")
    results = search_service.search(q, top_k=2)
    for r in results:
        meta = r["metadata"]
        print(f"  -> Match: {meta.get('original_name')} | Category: {meta.get('category')} | Score: {r['score']} (Semantic: {r['semantic_score']})")
