# app/schemas/message.py
from datetime import datetime
from pydantic import BaseModel, Field
from app.enums import MessageSender


class MessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)
    # sender isn't accepted from the client — see note below


class MessageResponse(BaseModel):
    id: int
    conversation_id: int
    sender: MessageSender
    content: str
    created_at: datetime

    class Config:
        from_attributes = True