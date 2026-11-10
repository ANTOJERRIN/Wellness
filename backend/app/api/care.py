"""Patient/doctor consultations: explicit assignment, private messages, no implicit profile sharing."""
from datetime import datetime
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.gemini import generate_health_answer, GeminiUnavailable
from app.core.rate_limit import consume_limit
from app.models.db_models import User, Consultation, ConsultationMessage, ChatSession, HealthProfile

router = APIRouter(prefix="/care", tags=["care"])


class ConsultationRequest(BaseModel):
    doctorId: int
    reason: str = Field(min_length=10, max_length=2000)


class MessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class StatusRequest(BaseModel):
    status: Literal['in_progress', 'closed']


def participant(db, consultation_id, user):
    row = db.query(Consultation).filter(
        Consultation.id == consultation_id,
        or_(Consultation.patientId == user.id, Consultation.doctorId == user.id),
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Consultation not found")
    if user.id == row.doctorId and user.role != 'doctor':
        raise HTTPException(status_code=403, detail="An approved doctor account is required")
    return row


def save(db):
    try:
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(status_code=503, detail="Unable to save consultation. Please try again.")


def describe(row, names):
    return {'id': row.id, 'patientName': names.get(row.patientId, 'Patient'),
            'doctorName': names.get(row.doctorId, 'Doctor'), 'reason': row.reason,
            'status': row.status, 'createdAt': row.createdAt, 'updatedAt': row.updatedAt}


@router.get('/dashboard')
def dashboard(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    criterion = Consultation.doctorId == user.id if user.role == 'doctor' else Consultation.patientId == user.id
    rows = [] if user.role == 'doctor_pending' else db.query(Consultation).filter(criterion).order_by(Consultation.updatedAt.desc()).all()
    ids = {value for row in rows for value in (row.patientId, row.doctorId)}
    names = dict(db.query(User.id, User.name).filter(User.id.in_(ids)).all()) if ids else {}
    profile = db.query(HealthProfile).filter(HealthProfile.userId == user.id).first()
    fields = ('medicalHistory', 'lifestyle', 'symptoms', 'allergies', 'medications')
    return {
        'role': user.role, 'name': user.name,
        'consultations': [describe(row, names) for row in rows],
        'activeConsultations': sum(row.status != 'closed' for row in rows),
        'chatSessions': db.query(ChatSession).filter(ChatSession.userId == user.id, ChatSession.isActive == True).count(),
        'profileFieldsCompleted': sum(bool(getattr(profile, field, None)) for field in fields),
        'ai': {'configured': bool(settings.gemini_api_key), 'provider': 'Gemini', 'model': settings.GEMINI_MODEL},
    }


@router.get('/doctors')
def doctors(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return [{'id': row.id, 'name': row.name} for row in db.query(User).filter(User.role == 'doctor', User.isActive == True).order_by(User.name).all()]


@router.post('/consultations', status_code=201)
def request_consultation(body: ConsultationRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role not in {'user', 'patient'}:
        raise HTTPException(status_code=403, detail='Only patient accounts can request consultations')
    reason = body.reason.strip()
    if len(reason) < 10:
        raise HTTPException(status_code=422, detail='Please describe your request in at least 10 characters')
    doctor = db.query(User).filter(User.id == body.doctorId, User.role == 'doctor', User.isActive == True).first()
    if not doctor:
        raise HTTPException(status_code=400, detail='Please choose an available approved doctor')
    consume_limit(db, f'care:request:{user.id}', 10, 3600)
    row = Consultation(id=str(uuid4()), patientId=user.id, doctorId=doctor.id, reason=reason)
    db.add(row)
    save(db)
    return describe(row, {user.id: user.name, doctor.id: doctor.name})


@router.get('/consultations/{consultation_id}/messages')
def messages(consultation_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    participant(db, consultation_id, user)
    rows = db.query(ConsultationMessage, User.name).join(User, User.id == ConsultationMessage.senderId).filter(ConsultationMessage.consultationId == consultation_id).order_by(ConsultationMessage.createdAt, ConsultationMessage.id).all()
    return [{'id': row.id, 'content': row.content, 'senderName': name, 'isOwn': row.senderId == user.id, 'createdAt': row.createdAt} for row, name in rows]


@router.post('/consultations/{consultation_id}/messages', status_code=201)
def send_message(consultation_id: str, body: MessageRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = participant(db, consultation_id, user)
    if row.status == 'closed':
        raise HTTPException(status_code=409, detail='This consultation is closed')
    content = body.content.strip()
    if not content:
        raise HTTPException(status_code=422, detail='Please enter a message')
    consume_limit(db, f'care:message:{user.id}', 30, 60)
    # Serialize with closure updates: a closed consultation cannot receive new messages.
    changed = db.query(Consultation).filter(Consultation.id == row.id, Consultation.status != 'closed').update({'updatedAt': datetime.utcnow()}, synchronize_session=False)
    if changed != 1:
        db.rollback()
        raise HTTPException(status_code=409, detail='This consultation is closed')
    message = ConsultationMessage(id=str(uuid4()), consultationId=row.id, senderId=user.id, content=content)
    db.add(message)
    save(db)
    return {'id': message.id, 'content': message.content, 'senderName': user.name, 'isOwn': True, 'createdAt': message.createdAt}


@router.patch('/consultations/{consultation_id}')
def update_status(consultation_id: str, body: StatusRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = participant(db, consultation_id, user)
    if user.role != 'doctor' or row.doctorId != user.id:
        raise HTTPException(status_code=403, detail='Only the assigned doctor can update status')
    changed = db.query(Consultation).filter(Consultation.id == row.id, Consultation.status != 'closed').update({'status': body.status, 'updatedAt': datetime.utcnow()}, synchronize_session=False)
    if changed != 1:
        db.rollback()
        raise HTTPException(status_code=409, detail='This consultation is already closed')
    save(db)
    return {'status': body.status}


@router.post('/ai/check')
async def check_ai(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    consume_limit(db, f'ai:check:{user.id}', 3, 300)
    try:
        await run_in_threadpool(generate_health_answer, 'Return a short greeting in the answer field. This is a connection test; no patient data is included.')
    except GeminiUnavailable as error:
        return {'connected': False, 'reason': error.reason}
    return {'connected': True, 'reason': None}
