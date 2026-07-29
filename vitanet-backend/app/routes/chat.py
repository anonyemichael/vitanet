# app/routers/chat.py
from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.chat import ChatRequest
from app.services.ai_agent import run_agent

router = APIRouter(prefix="/chat", tags=["chat"])

# app/routers/chat.py
@router.post("/{user_id}")
def chat(user_id: UUID, payload: ChatRequest, db: Session = Depends(get_db)):
    return run_agent(db, user_id, payload.message)