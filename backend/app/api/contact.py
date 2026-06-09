import re
import logging
from fastapi import APIRouter, HTTPException, status
from app.schemas.pydantic_objs import ContactForm

logger = logging.getLogger("contact_api")

router = APIRouter(prefix="/contact", tags=["contact"])

EMAIL_REGEX = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
MAX_MESSAGE_LEN = 5000


@router.post("")
async def submit_contact(body: ContactForm):
    """Accept contact form submissions from users."""
    name = body.name.strip()
    email = body.email.strip().lower()
    message = body.message.strip()

    # Basic validation
    if len(name) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name must be at least 2 characters."
        )
    if not EMAIL_REGEX.match(email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid email address."
        )
    if len(message) < 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message must be at least 10 characters."
        )
    if len(message) > MAX_MESSAGE_LEN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Message cannot exceed {MAX_MESSAGE_LEN} characters."
        )

    # Log to server console (SMTP integration can be added here)
    logger.info(
        f"[CONTACT SUBMISSION] From: {name} <{email}> | "
        f"Message: {message[:200]}{'...' if len(message) > 200 else ''}"
    )

    return {
        "success": True,
        "message": "Your message has been received. We'll get back to you shortly."
    }
