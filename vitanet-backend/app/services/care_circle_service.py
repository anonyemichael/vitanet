from uuid import UUID
from typing import Optional, List

from sqlalchemy.orm import Session

from app.models.care_circle import CareCircle, CareCircleStatus, Relationship
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
    _remove(db, care_circle)
    db.commit()
    return True


def _remove(db: Session, care_circle: CareCircle) -> None:
    """Delete a contact and its activity-feed rows (they point at it)."""
    from app.models.care_circle_activity import CareCircleActivity
    db.query(CareCircleActivity).filter(CareCircleActivity.care_circle_id == care_circle.id).delete(
        synchronize_session=False)
    db.delete(care_circle)

def contact_key(phone=None, email=None) -> str:
    """Same person, however the number is written."""
    from app.services.sms_service import normalize_phone
    return normalize_phone(phone) if phone and normalize_phone(phone) else (email or "").strip().lower()


def find_by_contact(db: Session, requester_id: UUID, phone=None, email=None) -> Optional[CareCircle]:
    key = contact_key(phone, email)
    if not key:
        return None
    for c in get_care_circle_for_user(db, requester_id):
        if contact_key(c.contact_phone, c.contact_email) == key:
            return c
    return None


def send_invites(db: Session, member: CareCircle) -> None:
    """Ask the contact to agree before they ever get an alert: email link and/or SMS (reply YES)."""
    from app.services import sms_service
    from app.services.health_alert_service import _person
    person = _person(db, member.requester_id)
    if member.contact_email:
        try:
            from app.services.verify_care_email import send_care_circle_invite
            send_care_circle_invite(to_email=member.contact_email, requester_name=person,
                                    invite_token=member.invite_token)
        except Exception:
            import logging
            logging.getLogger(__name__).exception("Care-circle invite email failed")
    if member.contact_phone:
        sms_service.send(member.contact_phone, sms_service.CARE_INVITE.format(person=person))


_RELATION = {"partner": ("husband", "wife", "spouse", "partner", "fianc"),
             "doctor": ("doctor", "nurse", "clinician", "midwife", "chw"),
             "friend": ("friend", "neighbour", "neighbor", "colleague"),
             "family": ("family", "mother", "father", "mum", "mom", "dad", "son", "daughter", "brother", "sister",
                        "aunt", "uncle", "cousin", "grand", "child", "parent", "guardian")}


def relation_of(text) -> Relationship:
    t = (text or "").lower()
    for rel, words in _RELATION.items():
        if any(w in t for w in words):
            return Relationship(rel)
    return Relationship.OTHER


def sync_from_app(db: Session, requester_id: UUID, contacts, remove_missing: bool = False) -> None:
    """New contacts from the app are added and invited (once). With remove_missing (the person edited the list),
    contacts no longer in it are removed here too, so they stop getting alerts."""
    wanted = {}
    for c in contacts:
        phone = (c.phone or "").strip() or None
        email = (c.email or "").strip() or None
        key = contact_key(phone, email)
        if key and c.name.strip():
            wanted[key] = (c, phone, email)
    for row in get_care_circle_for_user(db, requester_id) if remove_missing else []:
        if contact_key(row.contact_phone, row.contact_email) not in wanted:
            _remove(db, row)
    db.flush()
    for key, (c, phone, email) in wanted.items():
        if find_by_contact(db, requester_id, phone, email) is None:
            member = CareCircle(requester_id=requester_id, full_name=c.name.strip(), contact_phone=phone,
                                contact_email=email, relationship=relation_of(c.relation),
                                status=CareCircleStatus.PENDING)
            db.add(member)
            db.commit()
            db.refresh(member)
            send_invites(db, member)
    db.commit()
