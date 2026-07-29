from uuid import UUID
from typing import Optional, List

from sqlalchemy.orm import Session

from app.models.care_circle import CareCircle, CareCircleStatus
from app.schemas.user import CareCircleMemberInput


def create_care_circle_member(db: Session, requester_id: UUID, data: CareCircleMemberInput) -> CareCircle:
    care_circle = CareCircle(
        requester_id=requester_id,
        full_name=data.full_name,
        contact_email=data.contact_email,
        contact_phone=data.contact_phone,
        relationship=data.relationship,
        is_primary=data.is_primary,
        status=CareCircleStatus.PENDING,
    )
    db.add(care_circle)
    db.flush()
    return care_circle


def create_care_circle_members(db: Session, requester_id: UUID, members: List[CareCircleMemberInput]) -> List[CareCircle]:
    return [create_care_circle_member(db, requester_id, member) for member in members]


def get_care_circle_by_id(db: Session, care_circle_id: UUID) -> Optional[CareCircle]:
    return db.query(CareCircle).filter(CareCircle.id == care_circle_id).first()


def get_care_circle_by_token(db: Session, invite_token: str) -> Optional[CareCircle]:
    return db.query(CareCircle).filter(CareCircle.invite_token == invite_token).first()


def get_care_circle_for_user(db: Session, requester_id: UUID) -> List[CareCircle]:
    return db.query(CareCircle).filter(CareCircle.requester_id == requester_id).all()


def update_care_circle_status(db: Session, invite_token: str, status: CareCircleStatus) -> Optional[CareCircle]:
    care_circle = get_care_circle_by_token(db, invite_token)
    if not care_circle:
        return None
    care_circle.status = status
    db.commit()
    db.refresh(care_circle)
    return care_circle


def update_care_circle_member(db: Session, care_circle_id: UUID, updates: dict) -> Optional[CareCircle]:
    care_circle = get_care_circle_by_id(db, care_circle_id)
    if not care_circle:
        return None
    for field, value in updates.items():
        setattr(care_circle, field, value)
    db.commit()
    db.refresh(care_circle)
    return care_circle


def delete_care_circle_member(db: Session, care_circle_id: UUID) -> bool:
    care_circle = get_care_circle_by_id(db, care_circle_id)
    if not care_circle:
        return False
    db.delete(care_circle)
    db.commit()
    return True