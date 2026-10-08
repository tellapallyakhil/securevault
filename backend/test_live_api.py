import asyncio
import httpx
from app.main import app

async def test_full_pipeline():
    print("\n========================================================")
    print("TESTING LIVE SECUREVAULT AI API WITH SUPABASE POSTGRESQL")
    print("========================================================")
    
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Health check
        res = await client.get("/")
        print("\n1. Root Health Check:", res.status_code, res.json()["service"])
        assert res.status_code == 200

        # 2. Register / Login test user
        email = "balaji.narendra@securevault.ai"
        password = "SecureMasterPassword@2026"
        
        reg_res = await client.post("/api/v1/auth/register", json={
            "email": email,
            "password": password,
            "full_name": "Balaji Talluri"
        })
        
        if reg_res.status_code == 200:
            token = reg_res.json()["access_token"]
            print("2. User Registered successfully in Supabase DB!")
        else:
            # Login if already exists
            login_res = await client.post("/api/v1/auth/login", json={
                "email": email,
                "password": password,
                "client_ip": "127.0.0.1"
            })
            assert login_res.status_code == 200
            token = login_res.json()["access_token"]
            print("2. User Logged in successfully! JWT received.")

        headers = {"Authorization": f"Bearer {token}"}

        # 3. Document Intake (OCR + PII + AES-256-GCM + FAISS Dense Vector Embedding)
        print("\n3. Testing Document Intake Pipeline...")
        sample_doc = (
            b"SECUREVAULT MEDICAL RECORD: Patient Balaji Talluri. DOB: 14/08/1998. "
            b"Aadhaar: 4921 8291 0192. Diagnosis: Routine cardiovascular checkup. "
            b"Prescription: Aspirin 75mg daily, Vitamin D3 supplement."
        )
        files = {"file": ("Medical_Prescription_Cardiology.txt", sample_doc, "text/plain")}
        
        upload_res = await client.post("/api/v1/documents/upload", headers=headers, files=files)
        print("Upload Status:", upload_res.status_code)
        doc_data = upload_res.json()
        print(f" -> Doc ID: {doc_data['id']}")
        print(f" -> Category: {doc_data['category']}")
        print(f" -> Sensitivity: {doc_data['sensitivity']}")
        print(f" -> PII Detected: {doc_data['pii_summary']['counts_by_type']}")
        assert upload_res.status_code == 200
        assert doc_data["category"] == "Medical"
        assert doc_data["sensitivity"] == "HIGH"

        # 4. Dense Vector Semantic Search (using Sentence Transformers + FAISS)
        print("\n4. Testing Dense Vector Semantic Search (FAISS)...")
        search_res = await client.post("/api/v1/documents/search", headers=headers, json={
            "query": "Where is my doctor's prescription for cardiovascular medicine?",
            "top_k": 3
        })
        results = search_res.json()
        print(f"Query returned {len(results)} matches:")
        for r in results:
            print(f" -> Match: '{r['original_name']}' | Cosine Similarity Score: {r['score']:.4f} | Category: {r['category']}")
        assert len(results) > 0
        assert results[0]["original_name"] == "Medical_Prescription_Cardiology.txt"

        # 5. Isolation Forest Behavioral Anomaly Telemetry
        print("\n5. Testing Isolation Forest Real-Time Behavioral Security...")
        # A) Normal activity
        norm_res = await client.post("/api/v1/security/telemetry", headers=headers, json={
            "hour": 14.0,
            "access_frequency": 2.0,
            "ip_changed": False,
            "failed_attempts": 0,
            "high_sens_count": 1
        })
        norm_data = norm_res.json()
        print(f" -> Daytime Access: Risk Level={norm_data['risk_level']} (Score={norm_data['risk_score']}/100)")
        assert norm_data["is_anomaly"] == False

        # B) Midnight Burst Attacker
        attack_res = await client.post("/api/v1/security/telemetry", headers=headers, json={
            "hour": 3.2,
            "access_frequency": 42.0,
            "ip_changed": True,
            "failed_attempts": 5,
            "high_sens_count": 10
        })
        attack_data = attack_res.json()
        print(f" -> Attack Simulation: Risk Level={attack_data['risk_level']} (Score={attack_data['risk_score']}/100)")
        print(f"    Reasons: {attack_data['reasons']}")
        assert attack_data["is_anomaly"] == True
        assert attack_data["risk_level"] == "CRITICAL"

        # 6. Security Status Overview
        sec_res = await client.get("/api/v1/security/status", headers=headers)
        sec_data = sec_res.json()
        print("\n6. Live Security Status Dashboard:")
        print(f" -> Total Documents in Supabase: {sec_data['total_documents']}")
        print(f" -> High Sensitivity Docs: {sec_data['high_sensitivity_count']}")
        print(f" -> Threat Level: {sec_data['active_threat_level']}")

    print("\n========================================================")
    print("ALL LIVE TESTS PASSED ON SUPABASE CLOUD POSTGRESQL!")
    print("========================================================\n")

if __name__ == "__main__":
    asyncio.run(test_full_pipeline())
