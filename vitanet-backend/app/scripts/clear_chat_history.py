# app/scripts/clear_chat_history.py
"""
Clear all chat messages for a given user.
Run: python -m app.scripts.clear_chat_history <user_id>
"""
import argparse
from uuid import UUID

from app.database.connection import SessionLocal
from app.models.chat import ChatMessage


def clear_chat_history(user_id: UUID):
    db = SessionLocal()
    try:
        deleted = db.query(ChatMessage).filter(ChatMessage.user_id == user_id).delete()
        db.commit()
        print(f"Deleted {deleted} chat messages for user {user_id}")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id", type=UUID)
    args = parser.parse_args()
    clear_chat_history(args.user_id)