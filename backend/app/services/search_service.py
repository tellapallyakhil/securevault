import os
import re
import json
from pathlib import Path
from typing import List, Dict, Any, Optional
import numpy as np
import faiss
from fastembed import TextEmbedding

from app.core.config import settings

class SearchService:
    """
    Production-Grade Hybrid Semantic Vector Search Engine:
    - Model: sentence-transformers/all-MiniLM-L6-v2 (384-dim dense semantic embeddings)
    - Vector Database / Index: FAISS IndexFlatIP (Cosine similarity on normalized vectors)
    - Hybrid Ranking: Dense Vector Cosine Similarity + Lexical Token Matching
    - Context Enrichment: Embeds filename, category, sensitivity, domain concepts, & OCR content
    - Multi-tenant / User Isolation: Filter by user_id
    """

    def __init__(self):
        self.dimension = 384  # 384-dimensional dense vectors
        self.embed_model = None
        self.index = None
        self.doc_ids: List[str] = []
        self.doc_metadata: Dict[str, Dict[str, Any]] = {}
        self.doc_texts: Dict[str, str] = {}
        self.initialized = False

    def lazy_load(self):
        if self.initialized:
            return
            
        print("Initializing Dense Vector Search Engine (all-MiniLM-L6-v2 + FAISS)...")
        # Load Sentence Transformers model via fastembed ONNX runtime
        self.embed_model = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")
        
        # Initialize FAISS Index (Inner Product on L2-normalized vectors = Cosine Similarity)
        self.index = faiss.IndexFlatIP(self.dimension)
        
        self.load_index()
        self.initialized = True
        print(f"FAISS vector index loaded with {self.index.ntotal} vectors.")

    @classmethod
    def build_semantic_document_text(
        cls,
        filename: str,
        category: str = "General",
        sensitivity: str = "LOW",
        text_or_preview: str = ""
    ) -> str:
        """
        Enriches document metadata and text into a structured semantic representation
        for the BERT sentence-transformer model.
        """
        clean_name = Path(filename).stem.replace("_", " ").replace("-", " ")
        ext = Path(filename).suffix.lower()
        
        # Domain concept tags
        tags = []
        lower_name = (filename + " " + category).lower()
        if "resume" in lower_name or "cv" in lower_name:
            tags.append("curriculum vitae resume job application career employment work history education candidate skills profile")
        if category.lower() == "medical" or any(w in lower_name for w in ["health", "prescription", "cardio", "doctor", "hospital"]):
            tags.append("medical prescription doctor hospital healthcare clinic diagnosis patient illness cardiology medication pharmacy drugs pills")
        if category.lower() == "financial" or any(w in lower_name for w in ["tax", "invoice", "bill", "salary", "audit", "payment", "revenue", "aws"]):
            tags.append("financial invoice receipt tax filing payment billing corporate revenue audit expense bank statement transaction")
        if category.lower() == "identity" or any(w in lower_name for w in ["id", "aadhaar", "pan", "passport", "citizen", "license"]):
            tags.append("government identity proof citizenship passport aadhaar card pan card national identification document")

        tag_str = " ".join(tags)
        clean_text = (text_or_preview or "").strip()
        # Remove placeholder noise
        clean_text = re.sub(r'\[(?:Extracted from|PDF document|Failed to).*?\]', '', clean_text).strip()

        semantic_str = (
            f"Document Title: {clean_name} ({filename}). "
            f"Category: {category}. "
            f"Sensitivity: {sensitivity}. "
            f"Domain Concepts: {tag_str}. "
            f"Content: {clean_text}"
        ).strip()
        
        return semantic_str

    def get_embedding(self, text: str) -> np.ndarray:
        """
        Converts text into a normalized 384-dimensional dense semantic vector.
        """
        self.lazy_load()
        if not text or not text.strip():
            text = "empty document"
            
        embeddings = list(self.embed_model.embed([text]))
        vec = np.array(embeddings[0], dtype=np.float32)
        norm = np.linalg.norm(vec)
        if norm > 0:
            vec = vec / norm
        return vec

    def add_document(
        self,
        doc_id: str,
        text: str,
        metadata: Dict[str, Any]
    ):
        """
        Indexes document into the FAISS vector database with enriched semantic context.
        """
        self.lazy_load()
        filename = metadata.get("original_name") or metadata.get("name") or doc_id
        category = metadata.get("category", "General")
        sensitivity = metadata.get("sensitivity", "LOW")

        # Build enriched semantic text
        enriched_text = self.build_semantic_document_text(
            filename=filename,
            category=category,
            sensitivity=sensitivity,
            text_or_preview=text
        )

        emb = self.get_embedding(enriched_text)
        
        # If doc_id already in index, rebuild clean to avoid duplicate vector accumulation
        if doc_id in self.doc_ids:
            idx = self.doc_ids.index(doc_id)
            self.doc_ids.pop(idx)
            # Reconstruct index without this item
            self._rebuild_index_with_new_doc(doc_id, emb, metadata, enriched_text)
        else:
            self.index.add(np.array([emb], dtype=np.float32))
            self.doc_ids.append(doc_id)
            metadata["text_preview"] = text[:300] if text else enriched_text[:300]
            metadata["semantic_context"] = enriched_text[:300]
            self.doc_metadata[doc_id] = metadata
            self.doc_texts[doc_id] = enriched_text
            self.save_index()

        print(f"Indexed doc '{filename}' (ID: {doc_id}) into FAISS. Total vectors: {self.index.ntotal}")

    def _rebuild_index_with_new_doc(
        self,
        new_doc_id: str,
        new_emb: np.ndarray,
        new_metadata: Dict[str, Any],
        new_text: str
    ):
        """Helper to rebuild FAISS index cleanly when replacing an existing document."""
        old_ids = list(self.doc_ids)
        self.doc_ids = []
        self.index = faiss.IndexFlatIP(self.dimension)
        
        # Re-add existing docs
        for d_id in old_ids:
            if d_id in self.doc_texts:
                emb = self.get_embedding(self.doc_texts[d_id])
                self.index.add(np.array([emb], dtype=np.float32))
                self.doc_ids.append(d_id)
                
        # Add updated doc
        self.index.add(np.array([new_emb], dtype=np.float32))
        self.doc_ids.append(new_doc_id)
        new_metadata["text_preview"] = new_text[:300]
        self.doc_metadata[new_doc_id] = new_metadata
        self.doc_texts[new_doc_id] = new_text
        self.save_index()

    def search(
        self,
        query: str,
        top_k: int = 5,
        user_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Hybrid Semantic Search:
        1. Dense Vector Cosine Similarity via Sentence-BERT (MiniLM) + FAISS
        2. Lexical Token Overlap Score
        3. Strict User Isolation Filtering
        """
        self.lazy_load()
        if not self.doc_ids or self.index.ntotal == 0 or not query.strip():
            return []

        clean_query = query.strip()
        q_emb = self.get_embedding(clean_query)
        
        # Search all or a large pool in FAISS so user filtering doesn't truncate results
        search_k = min(max(top_k * 5, 20), self.index.ntotal)
        distances, indices = self.index.search(np.array([q_emb], dtype=np.float32), search_k)

        query_tokens = set(re.findall(r'\w+', clean_query.lower()))

        scored_results = []
        for dist, idx in zip(distances[0], indices[0]):
            if 0 <= idx < len(self.doc_ids):
                doc_id = self.doc_ids[idx]
                meta = self.doc_metadata.get(doc_id, {})
                
                # Check user isolation
                doc_user = meta.get("user_id")
                if user_id and doc_user and doc_user != user_id:
                    continue

                semantic_score = float(dist)  # Cosine similarity in [-1, 1], normalized ~ [0, 1]

                # Lexical scoring
                doc_name = (meta.get("original_name") or meta.get("name") or "").lower()
                doc_cat = (meta.get("category") or "").lower()
                doc_text = (self.doc_texts.get(doc_id) or meta.get("text_preview") or "").lower()
                combined_corpus = f"{doc_name} {doc_cat} {doc_text}"
                
                lexical_matches = sum(1 for tok in query_tokens if tok in combined_corpus)
                lexical_score = min(lexical_matches / max(len(query_tokens), 1), 1.0)

                # Hybrid score with heavy vector weighting for semantic understanding
                final_score = (0.75 * semantic_score) + (0.25 * lexical_score)
                final_score = max(0.0, min(1.0, final_score))

                scored_results.append({
                    "doc_id": doc_id,
                    "score": round(final_score, 4),
                    "semantic_score": round(semantic_score, 4),
                    "lexical_score": round(lexical_score, 4),
                    "metadata": meta
                })

        # Sort by final hybrid score descending
        scored_results.sort(key=lambda x: x["score"], reverse=True)
        return scored_results[:top_k]

    def sync_documents(self, documents: List[Dict[str, Any]]):
        """
        Re-indexes an entire collection of documents from database into a fresh FAISS index.
        """
        self.lazy_load()
        print(f"Re-indexing {len(documents)} documents into FAISS Vector Search...")
        
        self.index = faiss.IndexFlatIP(self.dimension)
        self.doc_ids = []
        self.doc_metadata = {}
        self.doc_texts = {}

        if not documents:
            self.save_index()
            return

        enriched_texts = []
        doc_id_list = []
        metas = []

        for d in documents:
            d_id = str(d["id"])
            filename = d.get("original_name") or "Document"
            category = d.get("category") or "General"
            sensitivity = d.get("sensitivity") or "LOW"
            preview = d.get("summary_preview") or ""
            user_id = str(d.get("user_id") or "")

            enriched = self.build_semantic_document_text(
                filename=filename,
                category=category,
                sensitivity=sensitivity,
                text_or_preview=preview
            )
            
            meta = {
                "original_name": filename,
                "category": category,
                "sensitivity": sensitivity,
                "user_id": user_id,
                "text_preview": preview[:300],
                "file_size": d.get("file_size", 0),
                "created_at": str(d.get("created_at", ""))
            }

            enriched_texts.append(enriched)
            doc_id_list.append(d_id)
            metas.append((d_id, meta, enriched))

        # Batch embed for performance
        embeddings = list(self.embed_model.embed(enriched_texts))
        norm_vectors = []
        for vec in embeddings:
            arr = np.array(vec, dtype=np.float32)
            n = np.linalg.norm(arr)
            if n > 0:
                arr = arr / n
            norm_vectors.append(arr)

        matrix = np.array(norm_vectors, dtype=np.float32)
        self.index.add(matrix)
        self.doc_ids = doc_id_list

        for d_id, meta, enriched in metas:
            self.doc_metadata[d_id] = meta
            self.doc_texts[d_id] = enriched

        self.save_index()
        print(f"Successfully synchronized {self.index.ntotal} document vectors in FAISS!")

    def save_index(self):
        settings.FAISS_INDEX_DIR.mkdir(parents=True, exist_ok=True)
        index_file = settings.FAISS_INDEX_DIR / "index.bin"
        meta_file = settings.FAISS_INDEX_DIR / "metadata.json"
        
        if self.index is not None:
            try:
                faiss.write_index(self.index, str(index_file))
            except Exception as e:
                print(f"Error saving FAISS index: {e}")
                
        with open(meta_file, "w") as f:
            json.dump({
                "doc_ids": self.doc_ids,
                "doc_metadata": self.doc_metadata,
                "doc_texts": self.doc_texts
            }, f, indent=2)

    def load_index(self):
        index_file = settings.FAISS_INDEX_DIR / "index.bin"
        meta_file = settings.FAISS_INDEX_DIR / "metadata.json"
        
        if meta_file.exists():
            try:
                with open(meta_file, "r") as f:
                    data = json.load(f)
                    self.doc_ids = data.get("doc_ids", [])
                    self.doc_metadata = data.get("doc_metadata", {})
                    self.doc_texts = data.get("doc_texts", {})
            except Exception as e:
                print(f"Error reading index metadata: {e}")
                
        if index_file.exists():
            try:
                self.index = faiss.read_index(str(index_file))
            except Exception as e:
                print(f"Error loading FAISS index: {e}")
                self.index = faiss.IndexFlatIP(self.dimension)

search_service = SearchService()
