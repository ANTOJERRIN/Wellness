import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DBSession
from sqlalchemy.exc import SQLAlchemyError
from app.core.database import get_db
from app.models.db_models import User, HealthProfile
from app.schemas.pydantic_objs import HealthProfileUpdate
from app.api.deps import get_current_user

logger = logging.getLogger("profile_api")

router = APIRouter(prefix="/user", tags=["user"])

@router.get("/profile")
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        profile = db.query(HealthProfile).filter(HealthProfile.userId == current_user.id).first()
        
        # If no profile exists yet, return empty fields
        if not profile:
            profile_data = {
                "medicalHistory": "",
                "lifestyle": "",
                "symptoms": "",
                "allergies": "",
                "medications": ""
            }
        else:
            profile_data = {
                "medicalHistory": profile.medicalHistory or "",
                "lifestyle": profile.lifestyle or "",
                "symptoms": profile.symptoms or "",
                "allergies": profile.allergies or "",
                "medications": profile.medications or ""
            }

        return {
            "id": current_user.id,
            "name": current_user.name,
            "email": current_user.email,
            "role": current_user.role,
            "createdAt": current_user.createdAt,
            "healthProfile": profile_data
        }
    except SQLAlchemyError as e:
        logger.error(f"Database error fetching profile for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error retrieving profile details from database."
        )
    except Exception as e:
        logger.error(f"Unexpected error fetching profile for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred while fetching your profile."
        )

@router.put("/profile")
async def update_profile(
    profile_in: HealthProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        profile = db.query(HealthProfile).filter(HealthProfile.userId == current_user.id).first()
        
        if not profile:
            profile = HealthProfile(
                userId=current_user.id,
                medicalHistory=profile_in.medicalHistory,
                lifestyle=profile_in.lifestyle,
                symptoms=profile_in.symptoms,
                allergies=profile_in.allergies,
                medications=profile_in.medications
            )
            db.add(profile)
        else:
            if profile_in.medicalHistory is not None:
                profile.medicalHistory = profile_in.medicalHistory
            if profile_in.lifestyle is not None:
                profile.lifestyle = profile_in.lifestyle
            if profile_in.symptoms is not None:
                profile.symptoms = profile_in.symptoms
            if profile_in.allergies is not None:
                profile.allergies = profile_in.allergies
            if profile_in.medications is not None:
                profile.medications = profile_in.medications
                
        db.commit()
        db.refresh(profile)
        
        return {
            "success": True,
            "message": "Profile updated successfully",
            "healthProfile": {
                "medicalHistory": profile.medicalHistory,
                "lifestyle": profile.lifestyle,
                "symptoms": profile.symptoms,
                "allergies": profile.allergies,
                "medications": profile.medications
            }
        }
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error updating profile for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error saving profile details to database."
        )
    except Exception as e:
        logger.error(f"Unexpected error updating profile for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred while saving your profile."
        )
