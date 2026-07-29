# app/services/chat_service.py
from uuid import UUID
from sqlalchemy.orm import Session
from app.models.chat import ChatMessage, MessageRole

HISTORY_LIMIT = 20  # last N messages passed to the model — tune for your token budget


def save_message(
    db: Session,
    user_id: UUID,
    role: MessageRole,
    content: str | None = None,
    tool_calls: list | None = None,
    tool_name: str | None = None,
    tool_result=None,
) -> ChatMessage:
    msg = ChatMessage(
        user_id=user_id,
        role=role,
        content=content,
        tool_calls=tool_calls,
        tool_name=tool_name,
        tool_result=tool_result,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_recent_history(db: Session, user_id: UUID, limit: int = HISTORY_LIMIT) -> list[ChatMessage]:
    """Returns the last `limit` messages, oldest-first (ready to feed straight into the model)."""
    rows = (
        db.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    return list(reversed(rows))  # flip back to chronological order