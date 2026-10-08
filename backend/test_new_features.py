import asyncio
import httpx
from app.main import app

async def test_new_features():
    print("\n========================================================")
    print("TESTING NEW ADVANCED FEATURES (DEDUPLICATION, SHARING, REDACTION)")
    print("========================================================")
    
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # Login
        login_res = await client.post("/api/v1/auth/login", json={
            "email": "balaji.narendra@securevault.ai",
            "password": "SecureMasterPassword@2026",
            "client_ip": "127.0.0.1"
        })
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Test Deduplication
        print("\n1. Testing SHA-256 Deduplication...")
        content = b"INVOICE #9821: Vendor AWS. Amount: $1,400. PAN: ABCDE9999Z."
        files1 = {"file": ("Invoice_AWS_Sep.txt", content, "text/plain")}
        
        # First upload
        up1 = await client.post("/api/v1/documents/upload", headers=headers, files=files1)
        doc1_data = up1.json()
        doc_id = doc1_data["id"]
        print(f" -> First upload: Doc ID {doc_id} created.")

        # Duplicate upload
        files2 = {"file": ("Invoice_AWS_Sep_Copy.txt", content, "text/plain")}
        up2 = await client.post("/api/v1/documents/upload", headers=headers, files=files2)
        doc2_data = up2.json()
        print(f" -> Second upload with same content: is_duplicate = {doc2_data.get('is_duplicate')}")
        assert doc2_data.get("is_duplicate") == True
        assert doc2_data["id"] == doc_id
        print("SUCCESS: Cryptographic deduplication detected identical payload and saved storage!")

        # 2. Test Redacted PII Preview
        print("\n2. Testing PII-Masked Preview Endpoint...")
        red_res = await client.get(f"/api/v1/documents/{doc_id}/redacted", headers=headers)
        red_data = red_res.json()
        print(f" -> Raw text had PAN: ABCDE9999Z")
        print(f" -> Redacted output: {red_data['redacted_text']}")
        assert "[PAN_CARD_REDACTED]" in red_data["redacted_text"]
        print("SUCCESS: PII numbers successfully masked in privacy preview!")

        # 3. Test Secure Ephemeral Sharing Link with Password
        print("\n3. Testing Expiring Password-Protected Share Link...")
        share_res = await client.post(f"/api/v1/documents/{doc_id}/share", headers=headers, json={
            "expires_in_hours": 12,
            "password": "ClientAccessPassword#77",
            "max_downloads": 2
        })
        share_data = share_res.json()
        share_id = share_data["share_id"]
        print(f" -> Generated share link ID: {share_id}")
        print(f" -> Requires password: {share_data['requires_password']}")
        assert share_data["requires_password"] == True

        # Test download without password (should fail 401)
        unauth_dl = await client.get(f"/api/v1/share/{share_id}")
        print(f" -> Access without password status: {unauth_dl.status_code}")
        assert unauth_dl.status_code == 401

        # Test download with wrong password (should fail 401)
        wrong_pw_dl = await client.get(f"/api/v1/share/{share_id}?password=WrongPassword")
        assert wrong_pw_dl.status_code == 401

        # Test download with correct password (should succeed 200)
        auth_dl = await client.get(f"/api/v1/share/{share_id}?password=ClientAccessPassword#77")
        print(f" -> Access with valid password status: {auth_dl.status_code}")
        assert auth_dl.status_code == 200
        assert auth_dl.content == content
        print("SUCCESS: Encrypted file safely streamed to recipient upon password verification!")

    print("\n========================================================")
    print("ALL NEW ADVANCED FEATURES VERIFIED SUCCESSFULLY!")
    print("========================================================\n")

if __name__ == "__main__":
    asyncio.run(test_new_features())
