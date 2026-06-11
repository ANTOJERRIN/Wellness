import httpx
import uuid

base_url = "http://127.0.0.1:9005/api"

print("--- Testing Hospital Fetching ---")
r_hosp1 = httpx.get(f"{base_url}/nearby-hospitals", params={"state": "Karnataka"})
print(f"GET /nearby-hospitals -> Status: {r_hosp1.status_code}")
print("Response:", r_hosp1.json())
assert r_hosp1.status_code == 200
assert "hospitals" in r_hosp1.json()

r_hosp2 = httpx.get(f"{base_url}/hospitals/nearby", params={"state": "Karnataka"})
print(f"GET /hospitals/nearby -> Status: {r_hosp2.status_code}")
assert r_hosp2.status_code == 200

print("\n--- Registering & Authenticating Test User ---")
email = f"verified_user_{uuid.uuid4().hex[:6]}@example.com"
r_reg = httpx.post(f"{base_url}/auth/register", json={
    "name": "Integration Tester",
    "email": email,
    "password": "SecurePassword123"
})
print(f"POST /auth/register -> Status: {r_reg.status_code}")
assert r_reg.status_code == 200

r_login = httpx.post(f"{base_url}/auth/login", json={
    "email": email,
    "password": "SecurePassword123"
})
print(f"POST /auth/login -> Status: {r_login.status_code}")
assert r_login.status_code == 200
token = r_login.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

print("\n--- Creating AI Chat Session ---")
r_sess = httpx.post(f"{base_url}/chat/sessions", json={"title": "Verification Chat"}, headers=headers)
print(f"POST /chat/sessions -> Status: {r_sess.status_code}")
print("Response:", r_sess.json())
assert r_sess.status_code == 200
session_id = r_sess.json()["sessionId"]

print("\n--- Sending AI Chat Message (Gemini) ---")
r_msg = httpx.post(
    f"{base_url}/chat/sessions/{session_id}/messages",
    json={"content": "Suggest a simple 3-word healthy breakfast idea. Return only the 3 words, nothing else."},
    headers=headers,
    timeout=15.0
)
print(f"POST /chat/sessions/.../messages -> Status: {r_msg.status_code}")
print("Response:", r_msg.json())
assert r_msg.status_code == 200
assert "answer" in r_msg.json()
assert "followUpQuestion" in r_msg.json()

print("\nAll integration verification checks completed successfully!")
