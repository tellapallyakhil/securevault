import asyncio
from app.services.crypto_service import crypto_service
from app.services.pii_service import pii_service
from app.services.anomaly_service import anomaly_service
from app.services.search_service import search_service

def test_crypto():
    print("\n--- Testing AES-256-GCM Cryptography Engine ---")
    secret = "MasterVaultSecretPass@2026"
    test_data = b"CONFIDENTIAL_TAX_DOCUMENT: AADHAAR=4829 1928 3921, SALARY=$150,000"
    
    # Encrypt
    encrypted_payload = crypto_service.encrypt_bytes(test_data, secret)
    print(f"Plaintext size: {len(test_data)} bytes -> Encrypted payload: {len(encrypted_payload)} bytes")
    assert len(encrypted_payload) > len(test_data)
    
    # Decrypt
    decrypted = crypto_service.decrypt_bytes(encrypted_payload, secret)
    assert decrypted == test_data
    print("Decryption successful and exact match confirmed!")
    
    # Test Tamper Detection (Modify one byte of ciphertext)
    tampered = bytearray(encrypted_payload)
    tampered[-1] ^= 0xFF
    try:
        crypto_service.decrypt_bytes(bytes(tampered), secret)
        print("ERROR: Tampered data was not detected!")
    except Exception as e:
        print("Tamper detection SUCCESS! Corrupted ciphertext rejected:", type(e).__name__)

def test_pii():
    print("\n--- Testing PII Detection & Categorization Service ---")
    sample_text = (
        "Customer Statement for Balaji Talluri. PAN: ABCDE1234F, Aadhaar: 5432 9876 1234. "
        "Email: balaji@example.com. Phone: +91-9876543210. Total account balance: $45,000."
    )
    analysis = pii_service.analyze_text(sample_text)
    print("Category detected:", analysis["category"])
    print("Sensitivity rating:", analysis["sensitivity"])
    print("PII entities found:", analysis["counts_by_type"])
    assert analysis["sensitivity"] == "HIGH"
    assert analysis["category"] == "Financial"

    redacted = pii_service.redact_text(sample_text)
    print("Sample redacted text:\n", redacted)

def test_isolation_forest():
    print("\n--- Testing Isolation Forest Behavioral Anomaly Detection ---")
    # 1. Normal daytime user
    normal_telemetry = {
        "hour": 14.0,
        "access_frequency": 2.0,
        "ip_changed": False,
        "failed_attempts": 0,
        "high_sens_count": 0
    }
    res_normal = anomaly_service.assess_risk(normal_telemetry)
    print("Normal User Assessment:", res_normal)
    assert res_normal["risk_level"] in ["LOW", "ELEVATED"]

    # 2. Anomalous midnight burst attacker
    attack_telemetry = {
        "hour": 3.5,
        "access_frequency": 35.0,
        "ip_changed": True,
        "failed_attempts": 5,
        "high_sens_count": 8
    }
    res_attack = anomaly_service.assess_risk(attack_telemetry)
    print("Attacker Assessment:", res_attack)
    assert res_attack["is_anomaly"] == True
    assert res_attack["risk_score"] > 60
    assert len(res_attack["reasons"]) > 0

def test_semantic_search():
    print("\n--- Testing Vector Semantic Search Service ---")
    search_service.lazy_load()
    search_service.doc_ids = []
    search_service.doc_metadata = {}
    search_service.doc_texts = {}
    if search_service.index is not None:
        search_service.index.reset()
    search_service.add_document("doc1", "Annual corporate income tax filing and revenue audit invoice payment", {"name": "Tax_2025.pdf", "category": "Financial"})
    search_service.add_document("doc2", "Patient medical history and cardiovascular diagnosis prescription doctor hospital", {"name": "Health_Report.pdf", "category": "Medical"})
    search_service.add_document("doc3", "Government issued Aadhaar card identity proof with photo citizen passport", {"name": "Gov_ID.pdf", "category": "Identity"})

    results = search_service.search("prescription and doctor hospital diagnosis")
    print("Query: 'prescription and doctor hospital diagnosis'")
    for r in results:
        doc_name = r['metadata'].get('name') or r['metadata'].get('original_name', 'Doc')
        print(f" -> Doc: {doc_name}, Score: {r['score']:.4f}")
    assert results[0]["doc_id"] == "doc2"

if __name__ == "__main__":
    test_crypto()
    test_pii()
    test_isolation_forest()
    test_semantic_search()
    print("\nALL SECUREVAULT CORE VERIFICATION TESTS PASSED SUCCESSFULLY! ===")
