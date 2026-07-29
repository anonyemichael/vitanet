# app/models/chat.py
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Enum as SqlEnum, JSON
from sqlalchemy.dialects.postgresql import UUID
from app.database.base import Base


class MessageRole(str, enum.Enum):
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    role = Column(SqlEnum(MessageRole), nullable=False)
    content = Column(Text, nullable=True)
    tool_calls = Column(JSON, nullable=True)
    tool_name = Column(String, nullable=True)
    tool_result = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)