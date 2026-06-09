import uuid
import logging
# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DBSession
from sqlalchemy.exc import SQLAlchemyError
from app.core.database import get_db
from app.models.db_models import NewsletterSubscription
from app.schemas.pydantic_objs import NewsletterSubscribe

logger = logging.getLogger("newsletter_api")

router = APIRouter(prefix="/newsletter", tags=["newsletter"])


@router.post("/subscribe")
async def subscribe_newsletter(
    body: NewsletterSubscribe,
    db: DBSession = Depends(get_db)
):
    """Subscribe an email address to the newsletter."""
    email = body.email.lower().strip()

    try:
        existing = db.query(NewsletterSubscription).filter(
            NewsletterSubscription.email == email
        ).first()

        if existing:
            if existing.active:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This email is already subscribed to our newsletter."
                )
            else:
                # Reactivate
                existing.active = True
                db.commit()
                return {"message": "Successfully resubscribed to our newsletter!"}

        # New subscription
        new_sub = NewsletterSubscription(
            id=str(uuid.uuid4()),
            email=email,
            active=True
        )
        db.add(new_sub)
        db.commit()

        return {"message": "Successfully subscribed to our newsletter!"}

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error during newsletter subscription: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process newsletter subscription."
        )
