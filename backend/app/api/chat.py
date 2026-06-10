import json
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DBSession
from sqlalchemy.exc import SQLAlchemyError
import google.generativeai as genai
from app.core.database import get_db
from app.models.db_models import User, ChatSession, ChatMessage, HealthProfile
from app.schemas.pydantic_objs import ChatMessageCreate, ChatSessionCreate, ChatMessageResponse
from typing import List
from app.api.deps import get_current_user
from app.core.config import settings

logger = logging.getLogger("chat_api")

router = APIRouter(prefix="/chat", tags=["chat"])

# Initialize Gemini AI
if settings.GOOGLE_AI_API_KEY:
    try:
        genai.configure(api_key=settings.GOOGLE_AI_API_KEY)
        logger.info("Gemini AI API client successfully configured.")
    except Exception as e:
        logger.error(f"Error configuring Gemini AI Client: {e}")

SYSTEM_PROMPT = """You are a medical AI assistant. Your goal is to answer the user's question or ask for more information if needed.

IMPORTANT: You have access to the conversation history. Use this context to:
- Reference previous discussions and questions
- Provide more personalized responses based on what was discussed before
- Avoid asking for information already provided in previous messages
- Build upon previous advice or recommendations

You MUST respond in JSON format. The JSON object should conform to the following structure:
{{
  "answer": "string (This field is REQUIRED. It should contain the direct answer to the user's question. If you need to ask a follow-up question, this field should state that more information is needed, e.g., 'I need more information to help you effectively.')",
  "followUpQuestion": "string (This field is OPTIONAL. If you need more details from the user to provide a complete answer, include your specific follow-up question here. Otherwise, omit this field or provide an empty string.)"
}}

Example 1 (Direct Answer):
User question: "What are common flu symptoms?"
Your JSON response:
{{
  "answer": "Common flu symptoms include fever, cough, sore throat, runny or stuffy nose, muscle or body aches, headaches, and fatigue."
}}

Example 2 (Need More Information):
User question: "I have a cough, what could it be?"
Your JSON response:
{{
  "answer": "To understand what might be causing your cough, I need a bit more information.",
  "followUpQuestion": "Could you tell me more about your cough (e.g., is it dry or wet, how long have you had it) and if you have any other symptoms like fever or shortness of breath?"
}}

Carefully review the user's input:
Question: {question}
Medical History: {medical_history}
Lifestyle: {lifestyle}
Symptoms: {symptoms}
Previous Conversation: {history}

Based on this, decide if you can answer directly or if a follow-up question is necessary, and then generate the JSON response as described.
You should avoid providing medical advice or diagnoses. Instead, provide general information. If you are unsure, politely suggest that the user consult a healthcare professional.
"""

@router.post("/sessions")
async def create_chat_session(
    session_in: ChatSessionCreate,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        import uuid
        session_id = str(uuid.uuid4())
        db_session = ChatSession(
            userId=current_user.id,
            sessionId=session_id,
            title=session_in.title,
        )
        db.add(db_session)
        db.commit()
        db.refresh(db_session)
        return {"sessionId": session_id, "title": db_session.title, "createdAt": db_session.createdAt}
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error creating session for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create chat session in database."
        )

@router.get("/sessions")
async def list_chat_sessions(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        sessions = db.query(ChatSession).filter(
            ChatSession.userId == current_user.id,
            ChatSession.isActive == True
        ).order_by(ChatSession.updatedAt.desc()).all()
        
        return [
            {
                "sessionId": s.sessionId,
                "title": s.title or "Chat Session",
                "createdAt": s.createdAt,
                "updatedAt": s.updatedAt
            } for s in sessions
        ]
    except SQLAlchemyError as e:
        logger.error(f"Database error listing sessions for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve chat sessions."
        )

@router.post("/sessions/{session_id}/messages")
async def send_chat_message(
    session_id: str,
    message_in: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    if not settings.GOOGLE_AI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google Gemini API key not configured on backend."
        )

    try:
        # Verify session belongs to user
        chat_session = db.query(ChatSession).filter(
            ChatSession.sessionId == session_id,
            ChatSession.userId == current_user.id
        ).first()
        
        if not chat_session:
            raise HTTPException(status_code=404, detail="Chat session not found")

        # Save user message to database
        user_msg = ChatMessage(
            sessionId=chat_session.id,
            content=message_in.content,
            sender="user",
            timestamp=datetime.utcnow()
        )
        db.add(user_msg)
        db.commit() # Commit user message first to guarantee it is saved
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error writing user message: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to persist message to the database."
        )

    try:
        # Retrieve user health profile
        profile = db.query(HealthProfile).filter(HealthProfile.userId == current_user.id).first()
        med_hist = profile.medicalHistory if profile else ""
        lifestyle = profile.lifestyle if profile else ""
        symptoms = profile.symptoms if profile else ""

        # Load recent conversation history (last 10 messages)
        history_msgs = db.query(ChatMessage).filter(
            ChatMessage.sessionId == chat_session.id
        ).order_by(ChatMessage.timestamp.asc()).all()[-10:]
        
        history_str = "\n".join([f"{m.sender.upper()}: {m.content}" for m in history_msgs])
    except SQLAlchemyError as e:
        logger.error(f"Database error fetching context data: {e}")
        # Continue with empty context rather than crash the chat flow
        med_hist, lifestyle, symptoms, history_str = "", "", "", ""

    # Construct the full prompt
    formatted_prompt = SYSTEM_PROMPT.format(
        question=message_in.content,
        medical_history=med_hist or "None provided",
        lifestyle=lifestyle or "None provided",
        symptoms=symptoms or "None provided",
        history=history_str or "No previous messages"
    )

    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(
            formatted_prompt,
            generation_config={"response_mime_type": "application/json"}
        )
        
        # Safely check if response contains content
        if (
            not response.candidates 
            or not response.candidates[0].content 
            or not response.candidates[0].content.parts
        ):
            logger.error("Gemini API returned an empty/blocked response.")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="The AI assistant could not generate a response. The content may have been blocked or the API was unable to process it."
            )
            
        response_text = response.text
        
        # Parse JSON output safely
        try:
            response_data = json.loads(response_text)
            ai_answer = response_data.get("answer", "I need more information to help you effectively.")
            follow_up = response_data.get("followUpQuestion", "")
        except json.JSONDecodeError as je:
            logger.error(f"Failed to parse JSON from Gemini response: {response_text}. Error: {je}")
            # Resilient fallback if LLM produces invalid JSON
            ai_answer = response_text
            follow_up = ""
        
        # Save AI response
        ai_msg = ChatMessage(
            sessionId=chat_session.id,
            content=ai_answer,
            sender="ai",
            timestamp=datetime.utcnow(),
            isFollowUp=bool(follow_up),
            messageMetadata=json.dumps({"followUpQuestion": follow_up}) if follow_up else None
        )
        db.add(ai_msg)
        
        # Update chat session updatedAt
        chat_session.updatedAt = datetime.utcnow()
        db.commit()
        
        return {
            "answer": ai_answer,
            "followUpQuestion": follow_up
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Gemini API or database error during chat response generation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query Gemini AI or save response: {str(e)}"
        )


@router.get("/sessions/{session_id}/messages", response_model=List[ChatMessageResponse])
async def get_chat_messages(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        chat_session = db.query(ChatSession).filter(
            ChatSession.sessionId == session_id,
            ChatSession.userId == current_user.id
        ).first()
        
        if not chat_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chat session not found"
            )
            
        messages = db.query(ChatMessage).filter(
            ChatMessage.sessionId == chat_session.id
        ).order_by(ChatMessage.timestamp.asc()).all()
        
        return messages
    except SQLAlchemyError as e:
        logger.error(f"Database error fetching messages for session {session_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve messages from database."
        )


@router.delete("/sessions/{session_id}")
async def delete_chat_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    try:
        chat_session = db.query(ChatSession).filter(
            ChatSession.sessionId == session_id,
            ChatSession.userId == current_user.id
        ).first()
        
        if not chat_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chat session not found"
            )
            
        chat_session.isActive = False
        chat_session.updatedAt = datetime.utcnow()
        db.commit()
        
        return {"success": True, "message": "Session deleted successfully"}
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error deleting session {session_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete chat session from database."
        )


