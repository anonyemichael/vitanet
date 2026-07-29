from uuid import UUID
from typing import Optional

from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user import UserSignupInput


def create_user(db: Session, data: UserSignupInput) -> User:
    user = User(
        firebase_uid=data.firebase_uid,
        full_name=data.full_name,
        email=data.email,
        phone_number=data.phone_number,
        date_of_birth=data.date_of_birth,
        account_type=data.account_type,
    )
    db.add(user)
    db.flush()  # assigns user.id without committing, useful when called before other inserts in the same transaction
    return user


def get_user_by_id(db: Session, user_id: UUID) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_firebase_uid(db: Session, firebase_uid: str) -> Optional[User]:
    return db.query(User).filter(User.firebase_uid == firebase_uid).first()


def update_user(db: Session, user_id: UUID, updates: dict) -> Optional[User]:
    user = get_user_by_id(db, user_id)
    if not user:
        return None
    for field, value in updates.items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user_id: UUID) -> bool:
    user = get_user_by_id(db, user_id)
    if not user:
        return False
    db.delete(user)
    db.commit()
    return True