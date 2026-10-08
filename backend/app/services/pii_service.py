import re
from typing import Dict, List, Any

class PIIService:
    """
    Intelligent Personally Identifiable Information (PII) Detection & Redaction Service.
    Detects high-sensitivity entities: Aadhaar, PAN, SSN, Credit Cards, Emails, Phone Numbers.
    """

    PATTERNS = {
        "AADHAAR": r"\b[2-9]{1}[0-9]{3}\s?[0-9]{4}\s?[0-9]{4}\b",
        "PAN_CARD": r"\b[A-Z]{5}[0-9]{4}[A-Z]{1}\b",
        "SSN": r"\b(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b",
        "CREDIT_CARD": r"\b(?:\d{4}[ -]?){3}\d{4}\b",
        "EMAIL": r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b",
        "PHONE": r"\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b",
        "DATE_OF_BIRTH": r"\b(?:DOB|Date of Birth)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b",
        "PASSPORT": r"\b[A-Z][0-9]{7,8}\b"
    }

    CATEGORY_KEYWORDS = {
        "Educational": [
            "university", "academy", "education", "college", "school", "marksheet",
            "grade", "gpa", "cgpa", "sgpa", "semester", "ieee", "seminar", "student",
            "faculty", "professor", "symposium", "conference", "dean", "degree",
            "diploma", "certificate", "transcript", "btech", "mtech", "exam", "examnr",
            "examination", "test", "assessment", "coding questions", "question paper",
            "questions", "assignment", "coursework", "study material", "tutorial",
            "syllabus", "course", "curriculum", "lecture", "notes", "hall ticket",
            "admit card", "roll no", "enrollment"
        ],
        "Career": ["resume", "cv", "curriculum vitae", "experience", "skills", "projects", "employment", "candidate", "qualification", "work history"],
        "Financial": ["invoice", "receipt", "bank", "statement", "salary", "tax", "payment", "credit", "debit", "account", "balance", "total", "gstin", "amount", "due", "billing", "subtotal", "aws", "transaction"],
        "Identity": ["aadhaar", "pan", "passport", "license", "voter", "birth", "identity", "citizenship", "id card", "govt", "government of india", "dob", "gender", "national id"],
        "Medical": ["prescription", "diagnosis", "hospital", "patient", "clinical", "medication", "blood", "test report", "cardiology", "rx", "mg", "tablets", "capsule", "clinic", "treatment", "pharmacy", "doctor"],
        "Legal": ["contract", "agreement", "nda", "terms", "affidavit", "power of attorney", "deed", "court", "clause"]
    }

    @classmethod
    def analyze_text(cls, text: str) -> Dict[str, Any]:
        """
        Scans text for sensitive PII entities, counts, and assigns sensitivity level.
        """
        detected_entities = []
        counts_by_type = {}
        
        for pii_type, pattern in cls.PATTERNS.items():
            matches = list(re.finditer(pattern, text, re.IGNORECASE))
            if matches:
                counts_by_type[pii_type] = len(matches)
                for m in matches:
                    matched_val = m.group(0)
                    detected_entities.append({
                        "type": pii_type,
                        "text": matched_val[:4] + "***" if len(matched_val) > 4 else "***",
                        "start": m.start(),
                        "end": m.end()
                    })

        total_pii_count = sum(counts_by_type.values())
        
        # Determine sensitivity rating
        if any(t in counts_by_type for t in ["AADHAAR", "PAN_CARD", "CREDIT_CARD", "SSN", "PASSPORT"]):
            sensitivity = "HIGH"
        elif total_pii_count > 0:
            sensitivity = "MEDIUM"
        else:
            sensitivity = "LOW"
            
        # Classify document category
        category = cls.classify_document(text)

        return {
            "sensitivity": sensitivity,
            "total_pii_count": total_pii_count,
            "counts_by_type": counts_by_type,
            "entities": detected_entities,
            "category": category
        }

    @classmethod
    def redact_text(cls, text: str) -> str:
        """
        Replaces sensitive entities with redacted tags.
        """
        redacted = text
        for pii_type, pattern in cls.PATTERNS.items():
            redacted = re.sub(pattern, f"[{pii_type}_REDACTED]", redacted, flags=re.IGNORECASE)
        return redacted

    @classmethod
    def classify_document(cls, text: str) -> str:
        text_lower = text.lower()
        scores = {}
        for cat, keywords in cls.CATEGORY_KEYWORDS.items():
            score = sum(text_lower.count(kw) for kw in keywords)
            scores[cat] = score
        
        best_cat = max(scores, key=scores.get)
        if scores[best_cat] > 0:
            return best_cat
        return "General"

pii_service = PIIService()
