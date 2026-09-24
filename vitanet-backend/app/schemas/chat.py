# app/schemas/chat.py
from uuid import UUID
from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, ConfigDict, Field
from app.models.chat import MessageRole


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    role: MessageRole
    content: Optional[str] = None
    tool_calls: Optional[list[dict]] = None
    tool_name: Optional[str] = None
    tool_result: Optional[Any] = None
    created_at: datetime


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4_000)
    image_base64: Optional[str] = Field(default=None, max_length=8_000_000)


class ChatResponse(BaseModel):
    reply: str
    messages: list[ChatMessageOut]  # full turn, including any tool calls that happened along the way
