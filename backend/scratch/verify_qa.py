import httpx
import uuid

base_url = "http://127.0.0.1:9005/api"

print("=== 1. VERIFYING HOSPITALS ===")

# Test 1: GET /api/nearby-hospitals?state=Karnataka
r_hosp1 = httpx.get(f"{base_url}/nearby-hospitals", params={"state": "Karnataka"})
print(f"GET /nearby-hospitals?state=Karnataka -> Status: {r_hosp1.status_code}")
print("Response:", r_hosp1.json())
assert r_hosp1.status_code == 200
assert len(r_hosp1.json()["hospitals"]) > 0

# Test 2: GET /api/hospitals/nearby?state=Bangalore
r_hosp2 = httpx.get(f"{base_url}/hospitals/nearby", params={"state": "Bangalore"})
print(f"GET /hospitals/nearby?state=Bangalore -> Status: {r_hosp2.status_code}")
print("Response:", r_hosp2.json())
assert r_hosp2.status_code == 200
assert len(r_hosp2.json()["hospitals"]) > 0

# Test 3: GET /api/nearby-hospitals?state=UnknownState
r_hosp3 = httpx.get(f"{base_url}/nearby-hospitals", params={"state": "UnknownState"})
print(f"GET /nearby-hospitals?state=UnknownState -> Status: {r_hosp3.status_code}")
print("Response:", r_hosp3.json())
assert r_hosp3.status_code == 200
assert r_hosp3.json()["hospitals"] == []
assert "message" in r_hosp3.json()

print("\n=== 2. VERIFYING AI CHAT ===")

# Register/login user
email = f"qa_user_{uuid.uuid4().hex[:6]}@example.com"
httpx.post(f"{base_url}/auth/register", json={
    "name": "QA Tester",
    "email": email,
    "password": "QAPassword123"
})
r_login = httpx.post(f"{base_url}/auth/login", json={
    "email": email,
    "password": "QAPassword123"
})
token = r_login.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# Create chat session
r_sess = httpx.post(f"{base_url}/chat/sessions", json={"title": "QA Chat Session"}, headers=headers)
print(f"POST /chat/sessions -> Status: {r_sess.status_code}")
assert r_sess.status_code == 200
session_id = r_sess.json()["sessionId"]

# Send message
payload = {
    "content": "I have a headache and nausea. What general steps should I consider?"
}
r_msg = httpx.post(
    f"{base_url}/chat/sessions/{session_id}/messages",
    json=payload,
    headers=headers,
    timeout=15.0
)
print(f"POST /chat/sessions/{session_id}/messages -> Status: {r_msg.status_code}")
print("Response:", r_msg.json())
assert r_msg.status_code == 200
assert "answer" in r_msg.json()
assert "followUpQuestion" in r_msg.json()

print("\nAll QA verification assertions passed!")
