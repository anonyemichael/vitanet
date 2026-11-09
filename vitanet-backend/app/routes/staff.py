# app/routes/staff.py
"""Staff sign-up and approval. Staff register here; an approved hospital
admin reviews requests. Emails listed in BOOTSTRAP_ADMIN_EMAILS (verified
email only) become the first admin automatically."""
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import (
    CurrentUser,
    get_current_user,
    is_bootstrap_admin,
    require_admin,
)
from app.models.portal import AuditLog, FacilityRegistration
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus
from app.services.portal_events import hub

router = APIRouter(tags=["staff"])


class StaffRegisterIn(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    role: StaffRole = StaffRole.DOCTOR
    hospital_id: Optional[UUID] = None  # the registered facility to join
    facility: Optional[str] = Field(default=None, max_length=200)
    department: Optional[str] = Field(default=None, max_length=120)
    license_number: Optional[str] = Field(default=None, max_length=80)


class StaffOut(BaseModel):
    firebase_uid: str
    email: Optional[str] = None
    full_name: str
    role: StaffRole
    status: StaffStatus
    hospital_id: Optional[UUID] = None
    on_duty: bool = False
    facility: Optional[str] = None
    department: Optional[str] = None
    license_number: Optional[str] = None
    review_note: Optional[str] = None

    class Config:
        from_attributes = True


class ReviewIn(BaseModel):
    note: Optional[str] = Field(default=None, max_length=500)
    role: Optional[StaffRole] = None  # admin may adjust the role on approval


def _is_facility(db: Session, hospital_id: UUID) -> bool:
    return db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == hospital_id).first() is not None


@router.post("/staff/register", response_model=StaffOut)
def register_staff(
    payload: StaffRegisterIn,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current.anonymous:
        raise HTTPException(status_code=400, detail="Use an email or Google account for staff access")

    staff = db.query(StaffAccount).filter(StaffAccount.firebase_uid == current.uid).first()
    if staff and staff.status == StaffStatus.APPROVED:
        return staff  # already approved; registration can't change role/status
    if staff and staff.status in (StaffStatus.SUSPENDED, StaffStatus.REJECTED) and staff.hospital_id is not None \
            and payload.hospital_id != staff.hospital_id:
        # Can't escape a suspension or rejection by asking another hospital.
        raise HTTPException(status_code=409, detail="Ask your hospital's administrator to review your account")

    if staff is None:
        staff = StaffAccount(firebase_uid=current.uid)
        db.add(staff)

    staff.email = current.email
    staff.full_name = payload.full_name.strip()
    staff.role = payload.role
    staff.facility = payload.facility
    staff.department = payload.department
    staff.license_number = payload.license_number
    staff.status = StaffStatus.PENDING
    staff.review_note = None

    if is_bootstrap_admin(current):
        # The bootstrap admin creates their facility next (POST /portal/hospitals).
        staff.role = StaffRole.ADMIN
        staff.status = StaffStatus.APPROVED
        staff.reviewed_by = "bootstrap"
        staff.hospital_id = payload.hospital_id if payload.hospital_id and _is_facility(db, payload.hospital_id) else staff.hospital_id
    else:
        if payload.hospital_id is None or not _is_facility(db, payload.hospital_id):
            raise HTTPException(status_code=400, detail="Choose the hospital you work at")
        staff.hospital_id = payload.hospital_id

    db.commit()
    db.refresh(staff)
    hub.publish(staff.hospital_id, "team")
    return staff


@router.get("/staff/me", response_model=StaffOut)
def my_staff_status(
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    staff = db.query(StaffAccount).filter(StaffAccount.firebase_uid == current.uid).first()
    if staff is None:
        # A bootstrap admin signing in for the first time is provisioned here too.
        if is_bootstrap_admin(current):
            staff = StaffAccount(
                firebase_uid=current.uid,
                email=current.email,
                full_name=current.name or current.email,
                role=StaffRole.ADMIN,
                status=StaffStatus.APPROVED,
                reviewed_by="bootstrap",
            )
            db.add(staff)
            db.commit()
            db.refresh(staff)
            return staff
        raise HTTPException(status_code=404, detail="No staff account")
    return staff


@router.get("/admin/staff-requests", response_model=List[StaffOut])
def list_staff_requests(
    status: Optional[StaffStatus] = None,
    admin: StaffAccount = Depends(require_admin),
    db: Session = Depends(get_db),
):
    q = db.query(StaffAccount).filter(StaffAccount.hospital_id == admin.hospital_id)
    if status is not None:
        q = q.filter(StaffAccount.status == status)
    return q.order_by(StaffAccount.created_at.desc()).all()


class RoleIn(BaseModel):
    role: StaffRole


def _target(db: Session, uid: str, reviewer: StaffAccount) -> StaffAccount:
    staff = db.query(StaffAccount).filter(StaffAccount.firebase_uid == uid).first()
    if staff is None or staff.hospital_id is None or staff.hospital_id != reviewer.hospital_id:
        raise HTTPException(status_code=404, detail="Staff member not found")
    if staff.firebase_uid == reviewer.firebase_uid:
        raise HTTPException(status_code=400, detail="You can't review your own account")
    return staff


def _guard_last_admin(db: Session, staff: StaffAccount, new_status: StaffStatus, new_role: StaffRole):
    """A hospital must always keep at least one approved admin."""
    losing_admin = (staff.role == StaffRole.ADMIN and staff.status == StaffStatus.APPROVED
                    and (new_status != StaffStatus.APPROVED or new_role != StaffRole.ADMIN))
    if not losing_admin:
        return
    others = db.query(StaffAccount).filter(
        StaffAccount.hospital_id == staff.hospital_id, StaffAccount.role == StaffRole.ADMIN,
        StaffAccount.status == StaffStatus.APPROVED, StaffAccount.firebase_uid != staff.firebase_uid).count()
    if others == 0:
        raise HTTPException(status_code=409, detail="The hospital needs at least one administrator")


def _review(db: Session, uid: str, reviewer: StaffAccount, new_status: StaffStatus, payload: ReviewIn):
    staff = _target(db, uid, reviewer)
    new_role = payload.role if payload.role is not None and new_status == StaffStatus.APPROVED else staff.role
    _guard_last_admin(db, staff, new_status, new_role)
    staff.status = new_status
    staff.reviewed_by = reviewer.firebase_uid
    staff.review_note = payload.note
    staff.role = new_role
    if new_status != StaffStatus.APPROVED:
        staff.on_duty = False
    db.add(AuditLog(hospital_id=reviewer.hospital_id, actor_uid=reviewer.firebase_uid, actor_name=reviewer.full_name,
                    action=f"staff.{new_status.value}", target=staff.full_name, detail=payload.note))
    db.commit()
    db.refresh(staff)
    hub.publish(reviewer.hospital_id, "team")
    return staff


@router.post("/admin/staff-requests/{uid}/approve", response_model=StaffOut)
def approve_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.APPROVED, payload)


@router.post("/admin/staff-requests/{uid}/reinstate", response_model=StaffOut)
def reinstate_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    staff = _target(db, uid, admin)
    if staff.status not in (StaffStatus.SUSPENDED, StaffStatus.REJECTED):
        raise HTTPException(status_code=409, detail="Only suspended or rejected staff can be reinstated")
    return _review(db, uid, admin, StaffStatus.APPROVED, payload)


@router.post("/admin/staff-requests/{uid}/role", response_model=StaffOut)
def change_role(uid: str, payload: RoleIn, admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    staff = _target(db, uid, admin)
    if staff.status != StaffStatus.APPROVED:
        raise HTTPException(status_code=409, detail="Approve this person first")
    return _review(db, uid, admin, StaffStatus.APPROVED, ReviewIn(role=payload.role, note=staff.review_note))


@router.post("/admin/staff-requests/{uid}/reject", response_model=StaffOut)
def reject_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.REJECTED, payload)


@router.post("/admin/staff-requests/{uid}/suspend", response_model=StaffOut)
def suspend_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.SUSPENDED, payload)
