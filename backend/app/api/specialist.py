import logging
from fastapi import APIRouter, HTTPException, status
from app.schemas.pydantic_objs import SpecialistRequest

logger = logging.getLogger("specialist_api")

router = APIRouter(prefix="/specialist", tags=["specialist"])

DISCLAIMERS = [
    "These recommendations are for informational purposes only and should not replace professional medical advice.",
    "Please consult with a healthcare provider for proper diagnosis and treatment.",
    "If you experience severe or worsening symptoms, seek immediate medical attention.",
]


def get_mock_recommendations(
    symptoms: str, age: str, gender: str, severity: str, duration: str
) -> list[dict]:
    """
    Rule-based specialist matching engine.
    Translated directly from the Next.js getMockRecommendations function.
    """
    symptoms_lower = symptoms.lower()
    recommendations = []

    # Emergency conditions
    if "chest pain" in symptoms_lower and (
        "shortness of breath" in symptoms_lower or "breathing" in symptoms_lower
    ):
        recommendations.append({
            "specialty": "Emergency Medicine",
            "description": "Immediate medical attention for chest pain with breathing issues",
            "urgency": "high",
            "reason": "Chest pain with breathing difficulties can indicate a serious cardiac emergency",
            "additionalInfo": "Call 112 or go to the nearest emergency room immediately",
        })
    elif any(s in symptoms_lower for s in ["stroke", "paralysis", "slurred speech"]):
        recommendations.append({
            "specialty": "Emergency Medicine",
            "description": "Immediate medical attention for potential stroke symptoms",
            "urgency": "high",
            "reason": "These symptoms may indicate a stroke requiring immediate intervention",
            "additionalInfo": "Time is critical — seek emergency care immediately",
        })
    elif any(s in symptoms_lower for s in ["chest pain", "heart palpitation", "irregular heartbeat"]):
        recommendations.append({
            "specialty": "Cardiologist",
            "description": "Heart and cardiovascular system specialist",
            "urgency": "high" if severity in ("severe", "extreme") else "medium",
            "reason": "Your symptoms suggest a potential heart or cardiovascular issue",
            "additionalInfo": "A cardiologist can perform ECG, echocardiogram, and stress tests",
        })
    elif any(s in symptoms_lower for s in ["rash", "itching", "skin", "acne", "mole"]):
        recommendations.append({
            "specialty": "Dermatologist",
            "description": "Skin, hair, and nail specialist",
            "urgency": "high" if any(s in symptoms_lower for s in ["changing mole", "bleeding"]) else "low",
            "reason": "Your symptoms are related to skin conditions",
            "additionalInfo": "A dermatologist can diagnose and treat various skin conditions",
        })
    elif any(s in symptoms_lower for s in ["joint pain", "back pain", "arthritis", "bone"]):
        recommendations.append({
            "specialty": "Orthopedic Surgeon",
            "description": "Bone, joint, and musculoskeletal specialist",
            "urgency": "medium" if severity in ("severe", "extreme") else "low",
            "reason": "Your symptoms suggest musculoskeletal issues",
            "additionalInfo": "An orthopedist can evaluate bone and joint problems",
        })
    elif any(s in symptoms_lower for s in ["headache", "dizziness", "seizure", "numbness"]):
        recommendations.append({
            "specialty": "Neurologist",
            "description": "Brain and nervous system specialist",
            "urgency": "high" if ("seizure" in symptoms_lower or severity == "extreme") else "medium",
            "reason": "Your symptoms may be related to the nervous system",
            "additionalInfo": "A neurologist can evaluate brain and nerve function",
        })
    elif any(s in symptoms_lower for s in ["stomach", "abdominal pain", "nausea", "diarrhea", "vomiting"]):
        recommendations.append({
            "specialty": "Gastroenterologist",
            "description": "Digestive system specialist",
            "urgency": "medium" if severity in ("severe", "extreme") else "low",
            "reason": "Your symptoms are related to the digestive system",
            "additionalInfo": "A gastroenterologist can diagnose digestive disorders",
        })
    elif any(s in symptoms_lower for s in ["cough", "breathing", "lung", "asthma", "wheezing"]):
        recommendations.append({
            "specialty": "Pulmonologist",
            "description": "Lung and respiratory system specialist",
            "urgency": "high" if "difficulty breathing" in symptoms_lower else "medium",
            "reason": "Your symptoms are related to respiratory function",
            "additionalInfo": "A pulmonologist specializes in lung diseases and breathing disorders",
        })
    elif any(s in symptoms_lower for s in ["eye", "vision", "blurred", "blind"]):
        recommendations.append({
            "specialty": "Ophthalmologist",
            "description": "Eye and vision specialist",
            "urgency": "high" if "sudden vision loss" in symptoms_lower else "medium",
            "reason": "Your symptoms are related to eye or vision problems",
            "additionalInfo": "An ophthalmologist can diagnose and treat eye conditions",
        })
    elif any(s in symptoms_lower for s in ["ear", "nose", "throat", "hearing", "tonsil"]):
        recommendations.append({
            "specialty": "ENT Specialist",
            "description": "Ear, nose, and throat specialist",
            "urgency": "medium",
            "reason": "Your symptoms are related to ear, nose, or throat issues",
            "additionalInfo": "An ENT specialist can treat conditions affecting these areas",
        })
    elif gender == "female" and any(
        s in symptoms_lower for s in ["menstrual", "pregnancy", "pelvic"]
    ):
        recommendations.append({
            "specialty": "Gynecologist",
            "description": "Women's reproductive health specialist",
            "urgency": "medium",
            "reason": "Your symptoms are related to women's health",
            "additionalInfo": "A gynecologist specializes in women's reproductive health",
        })
    elif any(s in symptoms_lower for s in ["depression", "anxiety", "stress", "mental", "suicidal"]):
        recommendations.append({
            "specialty": "Psychiatrist",
            "description": "Mental health specialist",
            "urgency": "high" if "suicidal" in symptoms_lower else "medium",
            "reason": "Your symptoms suggest mental health concerns",
            "additionalInfo": "A psychiatrist can provide mental health evaluation and treatment",
        })
    elif any(s in symptoms_lower for s in ["diabetes", "thyroid", "hormone", "weight gain", "fatigue"]):
        recommendations.append({
            "specialty": "Endocrinologist",
            "description": "Hormonal and metabolic specialist",
            "urgency": "medium",
            "reason": "Your symptoms may be related to hormonal or metabolic conditions",
            "additionalInfo": "An endocrinologist can evaluate thyroid, diabetes, and related conditions",
        })

    # Default fallback
    if not recommendations:
        recommendations.append({
            "specialty": "Primary Care Physician",
            "description": "General medicine doctor for initial evaluation",
            "urgency": "medium",
            "reason": "A primary care physician can evaluate your symptoms and refer to specialists if needed",
            "additionalInfo": "Start with a general health checkup to determine next steps.",
        })

    return recommendations


@router.post("/recommend")
async def recommend_specialist(body: SpecialistRequest):
    """Return specialist recommendations based on symptoms and patient details."""
    if not body.symptoms.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Symptoms are required."
        )

    recommendations = get_mock_recommendations(
        symptoms=body.symptoms,
        age=body.age or "",
        gender=body.gender or "",
        severity=body.severity or "moderate",
        duration=body.duration or "",
    )

    logger.info(
        f"[SPECIALIST] Symptoms: '{body.symptoms[:80]}' → {len(recommendations)} recommendation(s)"
    )

    return {
        "recommendations": recommendations,
        "disclaimers": DISCLAIMERS,
    }
