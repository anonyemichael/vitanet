from typing import Annotated
# app/routers/chat.py
from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import CurrentUser, get_current_user, owned_user_id
from app.schemas.chat import ChatRequest
from app.services.ai_agent import run_agent

router = APIRouter(prefix="/chat", tags=["chat"])

# app/routers/chat.py
@router.post("/{user_id}")
def chat(user_id: Annotated[UUID, Depends(owned_user_id)], payload: ChatRequest, db: Session = Depends(get_db)):
    return run_agent(db, user_id, payload.message, payload.image_base64)
