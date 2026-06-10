import os
import joblib
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DBSession
from sqlalchemy.exc import SQLAlchemyError
from app.core.database import get_db
from app.schemas.pydantic_objs import RiskFeatures
from app.api.deps import get_current_user
from app.models.db_models import User, SecurityEvent

logger = logging.getLogger("risk_api")

router = APIRouter(prefix="/risk", tags=["risk"])

MODEL_PATH = "ml/heart_risk_model.pkl"
model = None

# Try loading the model on startup
if os.path.exists(MODEL_PATH):
    try:
        model = joblib.load(MODEL_PATH)
        logger.info(f"[SUCCESS] Loaded ML heart risk model from {MODEL_PATH}")
    except Exception as e:
        logger.error(f"[WARNING] Failed to load model from {MODEL_PATH}: {e}")
else:
    logger.info(f"[INFO] Model file not found at {MODEL_PATH}. Using standard fallback prediction engine.")

def fallback_cardiac_risk(features: RiskFeatures) -> dict:
    """
    Fallback mathematical engine when .pkl model is missing.
    Calculates probability based on clinical risk indicators.
    """
    try:
        score = 0.0
        # Age factor
        if features.age > 50:
            score += 1.5
        if features.age > 65:
            score += 1.5
            
        # Sex factor
        if features.sex == 1: # Male
            score += 1.0
            
        # Chest Pain type
        if features.chest_pain_type > 0:
            score += 2.0
            
        # BP factor
        if features.resting_bp > 140:
            score += 1.5
        if features.resting_bp > 160:
            score += 1.5
            
        # Cholesterol factor
        if features.cholesterol > 240:
            score += 1.5
            
        # Max heart rate factor
        if features.max_heart_rate < 120:
            score += 1.0
            
        # Angina
        if features.exercise_angina == 1:
            score += 2.0
            
        # Peak ST slope
        if features.st_slope == 0 or features.st_slope == 1:
            score += 1.0

        max_possible = 15.0
        risk_prob = min(max(score / max_possible, 0.05), 0.95)
        predicted_class = 1 if risk_prob > 0.5 else 0
        
        return {
            "risk_predicted": predicted_class,
            "risk_probability": round(risk_prob, 2),
            "engine": "fallback_clinical_matrix"
        }
    except Exception as e:
        logger.error(f"Error executing fallback cardiac risk logic: {e}")
        # Return a safe basic fallback prediction
        return {
            "risk_predicted": 0,
            "risk_probability": 0.1,
            "engine": "emergency_safe_fallback"
        }

@router.post("/predict")
async def predict_heart_risk(
    features: RiskFeatures,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        # Log the security/prediction attempt to DB
        log_details = f"Patient {current_user.id} requested heart risk prediction. Features: age={features.age}, bp={features.resting_bp}"
        event = SecurityEvent(
            type="cardiac_risk_prediction",
            severity="low",
            details=log_details,
            userId=current_user.id
        )
        db.add(event)
        db.commit()
    except SQLAlchemyError as se:
        db.rollback()
        logger.error(f"Database error writing SecurityEvent log: {se}")
        # Do not fail the endpoint because logging failed

    # If model is loaded, use it
    if model is not None:
        try:
            import pandas as pd
            df = pd.DataFrame([{
                'age': features.age,
                'sex': features.sex,
                'cp': features.chest_pain_type,
                'trestbps': features.resting_bp,
                'chol': features.cholesterol,
                'fbs': features.fasting_blood_sugar,
                'restecg': features.resting_ecg,
                'thalach': features.max_heart_rate,
                'exang': features.exercise_angina,
                'oldpeak': features.oldpeak,
                'slope': features.st_slope,
                'ca': 0.0,
                'thal': 2.0,
                'age.1': float(features.age),
                'gender': float(features.sex),
                'bmi': 25.0,
                'daily_steps': 7000.0,
                'sleep_hours': 7.0,
                'water_intake_l': 2.0,
                'calories_consumed': 2000.0,
                'smoker': 0.0,
                'alcohol': 0.0,
                'resting_hr': 70.0,
                'systolic_bp': float(features.resting_bp),
                'diastolic_bp': 80.0,
                'cholesterol': float(features.cholesterol),
                'family_history': 0.0,
                'disease_risk': 0.0
            }])
            prediction = int(model.predict(df)[0])
            prob = float(model.predict_proba(df)[0][1])
            return {
                "risk_predicted": prediction,
                "risk_probability": round(prob, 2),
                "engine": "ml_trained_model"
            }
        except Exception as e:
            logger.error(f"Error evaluating ML model. Falling back to clinical calculator: {e}")
            return fallback_cardiac_risk(features)
    
    # Otherwise fallback to manual calculator
    return fallback_cardiac_risk(features)
