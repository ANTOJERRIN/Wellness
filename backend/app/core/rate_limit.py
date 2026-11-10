"""Database-backed, fixed-window limits shared by API workers."""
import hashlib
import math
from datetime import datetime, timedelta

from fastapi import Depends, HTTPException, Request
from sqlalchemy import case, or_
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.db_models import RateLimit


# Per client address and endpoint; request bodies and forwarded headers are ignored.
AUTH_LIMITS = {
    "login": (10, 60),
    "register": (5, 300),
    "forgot-password": (5, 900),
    "reset-password": (10, 900),
    "refresh": (60, 60),
    "check-email": (20, 60),
    "logout": (60, 60),
}


def consume_limit(db: Session, key: str, limit: int, window: int) -> None:
    now = datetime.utcnow()
    expires = now + timedelta(seconds=window)
    try:
        # Insert first, then use one conditional UPDATE for both existing and
        # expired windows. Unique keys and row updates serialize concurrent workers.
        try:
            db.query(RateLimit).filter(RateLimit.resetTime < now - timedelta(days=1)).delete(synchronize_session=False)
            db.add(RateLimit(key=key, count=1, resetTime=expires))
            db.commit()
            return
        except IntegrityError:
            db.rollback()

        updated = db.query(RateLimit).filter(
            RateLimit.key == key,
            or_(RateLimit.resetTime <= now, RateLimit.count < limit),
        ).update({
            "count": case((RateLimit.resetTime <= now, 1), else_=RateLimit.count + 1),
            "resetTime": case((RateLimit.resetTime <= now, expires), else_=RateLimit.resetTime),
        }, synchronize_session=False)
        db.commit()
        if updated:
            # Bound stale state without removing counters for active windows.
            db.query(RateLimit).filter(RateLimit.resetTime < now - timedelta(days=1)).delete(synchronize_session=False)
            db.commit()
            return
        row = db.query(RateLimit).filter(RateLimit.key == key).first()
        retry_after = max(1, math.ceil((row.resetTime - now).total_seconds())) if row else window
        raise HTTPException(
            status_code=429, detail="Too many requests. Please try again later.",
            headers={"Retry-After": str(retry_after)},
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(status_code=503, detail="Request limiting is temporarily unavailable.")


def limit_auth_requests(request: Request, db: Session = Depends(get_db)) -> None:
    endpoint = request.url.path.rstrip("/").rsplit("/", 1)[-1]
    limit, window = AUTH_LIMITS.get(endpoint, (20, 60))
    address = request.client.host if request.client else "unknown"
    digest = hashlib.sha256(address.encode()).hexdigest()
    consume_limit(db, f"auth:{endpoint}:{digest}", limit, window)
