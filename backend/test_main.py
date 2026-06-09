import os
import unittest
import warnings
import json
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", category=UserWarning)

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models.db_models import User, HealthProfile, ChatSession, ChatMessage
from app.core.security import get_password_hash
from app.api.risk import fallback_cardiac_risk
from app.schemas.pydantic_objs import RiskFeatures

# Isolate Test Database URL
TEST_DATABASE_URL = "sqlite:///./test_temp.db"
test_engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

# Dependency override
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

class TestMedGenieBackend(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Create test tables
        Base.metadata.create_all(bind=test_engine)

    @classmethod
    def tearDownClass(cls):
        # Drop test tables and clean up DB file
        Base.metadata.drop_all(bind=test_engine)
        if os.path.exists("test_temp.db"):
            try:
                os.remove("test_temp.db")
            except Exception:
                pass

    def setUp(self):
        self.client = TestClient(app)
        self.db = TestingSessionLocal()
        # Clean data before each test
        for table in reversed(Base.metadata.sorted_tables):
            self.db.execute(table.delete())
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_root_endpoint(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Welcome to Med Genie Python Backend"})

    def test_fallback_risk_calculator(self):
        # High-risk features setup
        high_risk_features = RiskFeatures(
            age=72,
            sex=1,
            chest_pain_type=2,
            resting_bp=165,
            cholesterol=280,
            fasting_blood_sugar=1,
            resting_ecg=1,
            max_heart_rate=110,
            exercise_angina=1,
            oldpeak=2.5,
            st_slope=1
        )
        result = fallback_cardiac_risk(high_risk_features)
        self.assertIn("risk_probability", result)
        self.assertIn("risk_predicted", result)
        self.assertGreater(result["risk_probability"], 0.5)
        self.assertEqual(result["risk_predicted"], 1)

        # Low-risk features setup
        low_risk_features = RiskFeatures(
            age=22,
            sex=0,
            chest_pain_type=0,
            resting_bp=110,
            cholesterol=150,
            fasting_blood_sugar=0,
            resting_ecg=0,
            max_heart_rate=175,
            exercise_angina=0,
            oldpeak=0.0,
            st_slope=2
        )
        low_result = fallback_cardiac_risk(low_risk_features)
        self.assertLess(low_result["risk_probability"], 0.4)
        self.assertEqual(low_result["risk_predicted"], 0)

    def test_user_registration_and_login(self):
        # Register new user
        reg_payload = {
            "name": "John Doe",
            "email": "john@example.com",
            "password": "strongpassword123"
        }
        response = self.client.post("/api/auth/register", json=reg_payload)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["email"], "john@example.com")

        # Duplicate register error
        response = self.client.post("/api/auth/register", json=reg_payload)
        self.assertEqual(response.status_code, 400)
        self.assertIn("already exists", response.json()["detail"])

        # Login successful
        login_payload = {
            "email": "john@example.com",
            "password": "strongpassword123"
        }
        response = self.client.post("/api/auth/login", json=login_payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("access_token", data)
        self.assertIn("refresh_token", data)

        # Login failed invalid credentials
        login_payload = {
            "email": "john@example.com",
            "password": "wrongpassword"
        }
        response = self.client.post("/api/auth/login", json=login_payload)
        self.assertEqual(response.status_code, 400)
        self.assertIn("Incorrect email", response.json()["detail"])

    def test_user_profile(self):
        # Set up a test user
        hashed = get_password_hash("password123")
        user = User(name="Jane Doe", email="jane@example.com", password=hashed, confirmpassword=hashed)
        self.db.add(user)
        self.db.commit()

        # Login to get token
        login_response = self.client.post("/api/auth/login", json={"email": "jane@example.com", "password": "password123"})
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # GET Profile
        response = self.client.get("/api/user/profile", headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["name"], "Jane Doe")
        self.assertEqual(response.json()["healthProfile"]["medicalHistory"], "")

        # UPDATE Profile
        update_data = {
            "medicalHistory": "Hypertension, Asthma",
            "lifestyle": "Non-smoker, active",
            "symptoms": "Chest pain on exertion",
            "allergies": "Penicillin",
            "medications": "Albuterol inhaler"
        }
        response = self.client.put("/api/user/profile", json=update_data, headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["healthProfile"]["medicalHistory"], "Hypertension, Asthma")

        # GET Profile again to confirm update
        response = self.client.get("/api/user/profile", headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["healthProfile"]["lifestyle"], "Non-smoker, active")

    def test_heart_risk_prediction(self):
        # Set up a test user
        hashed = get_password_hash("password123")
        user = User(name="Jane Doe", email="jane@example.com", password=hashed, confirmpassword=hashed)
        self.db.add(user)
        self.db.commit()

        # Login to get token
        login_response = self.client.post("/api/auth/login", json={"email": "jane@example.com", "password": "password123"})
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        features = {
            "age": 55,
            "sex": 1,
            "chest_pain_type": 2,
            "resting_bp": 130,
            "cholesterol": 220,
            "fasting_blood_sugar": 0,
            "resting_ecg": 1,
            "max_heart_rate": 150,
            "exercise_angina": 0,
            "oldpeak": 1.2,
            "st_slope": 1
        }
        response = self.client.post("/api/risk/predict", json=features, headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn("risk_predicted", response.json())
        self.assertIn("risk_probability", response.json())

    @patch("app.api.chat.genai.GenerativeModel")
    def test_chat_flow(self, mock_generative_model):
        # Set up a test user
        hashed = get_password_hash("password123")
        user = User(name="Jane Doe", email="jane@example.com", password=hashed, confirmpassword=hashed)
        self.db.add(user)
        self.db.commit()

        # Login to get token
        login_response = self.client.post("/api/auth/login", json={"email": "jane@example.com", "password": "password123"})
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Mock Gemini response
        mock_model_instance = MagicMock()
        mock_response = MagicMock()
        mock_response.candidates = [
            MagicMock(
                content=MagicMock(
                    parts=[MagicMock(text='{"answer": "Based on history, seek medical attention.", "followUpQuestion": "Do you have dizziness?"}')]
                )
            )
        ]
        mock_response.text = '{"answer": "Based on history, seek medical attention.", "followUpQuestion": "Do you have dizziness?"}'
        mock_model_instance.generate_content.return_value = mock_response
        mock_generative_model.return_value = mock_model_instance

        # Create session
        sess_response = self.client.post("/api/chat/sessions", json={"title": "Test Chat"}, headers=headers)
        self.assertEqual(sess_response.status_code, 200)
        session_id = sess_response.json()["sessionId"]

        # List sessions
        list_response = self.client.get("/api/chat/sessions", headers=headers)
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()), 1)

        # Send message
        msg_payload = {"content": "I have chest tightness", "isFollowUp": False}
        msg_response = self.client.post(f"/api/chat/sessions/{session_id}/messages", json=msg_payload, headers=headers)
        self.assertEqual(msg_response.status_code, 200)
        self.assertEqual(msg_response.json()["answer"], "Based on history, seek medical attention.")
        self.assertEqual(msg_response.json()["followUpQuestion"], "Do you have dizziness?")

    def test_logout(self):
        # Set up a test user
        hashed = get_password_hash("password123")
        user = User(name="Jane Doe", email="jane@example.com", password=hashed, confirmpassword=hashed)
        self.db.add(user)
        self.db.commit()

        # Login to get token
        login_response = self.client.post("/api/auth/login", json={"email": "jane@example.com", "password": "password123"})
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Logout
        response = self.client.post("/api/auth/logout", headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["detail"], "Successfully logged out")

    def test_newsletter_subscribe(self):
        # First subscription
        response = self.client.post("/api/newsletter/subscribe", json={"email": "test@newsletter.com"})
        self.assertEqual(response.status_code, 200)
        self.assertIn("Successfully subscribed", response.json()["message"])

        # Duplicate subscription
        response = self.client.post("/api/newsletter/subscribe", json={"email": "test@newsletter.com"})
        self.assertEqual(response.status_code, 409)
        self.assertIn("already subscribed", response.json()["detail"])

    def test_contact_form(self):
        # Valid submission
        response = self.client.post("/api/contact", json={
            "name": "John Doe",
            "email": "john@example.com",
            "message": "This is a test message that is long enough."
        })
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["success"])

        # Invalid — message too short
        response = self.client.post("/api/contact", json={
            "name": "John",
            "email": "john@example.com",
            "message": "Hi"
        })
        self.assertEqual(response.status_code, 422)  # Pydantic validation error

    def test_specialist_recommendation(self):
        # Chest pain → cardiologist
        response = self.client.post("/api/specialist/recommend", json={
            "symptoms": "I have chest pain and heart palpitations",
            "age": "45",
            "gender": "male",
            "severity": "moderate"
        })
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("recommendations", data)
        self.assertGreater(len(data["recommendations"]), 0)
        specialties = [r["specialty"] for r in data["recommendations"]]
        self.assertIn("Cardiologist", specialties)

        # No symptoms → 422
        response = self.client.post("/api/specialist/recommend", json={
            "symptoms": ""
        })
        self.assertEqual(response.status_code, 422)

        # Unknown symptoms → fallback to Primary Care
        response = self.client.post("/api/specialist/recommend", json={
            "symptoms": "general body pain that is hard to categorize"
        })
        self.assertEqual(response.status_code, 200)
        specialties = [r["specialty"] for r in response.json()["recommendations"]]
        self.assertIn("Primary Care Physician", specialties)


if __name__ == "__main__":
    unittest.main()

