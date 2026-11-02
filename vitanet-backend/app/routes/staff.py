# app/routes/staff.py
"""Staff sign-up and approval. Staff register here; an approved hospital
admin reviews requests. Emails listed in BOOTSTRAP_ADMIN_EMAILS (verified
email only) become the first admin automatically."""
from typing import List, Optional

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
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus

router = APIRouter(tags=["staff"])


class StaffRegisterIn(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    role: StaffRole = StaffRole.DOCTOR
    facility: Optional[str] = Field(default=None, max_length=200)
    department: Optional[str] = Field(default=None, max_length=120)
    license_number: Optional[str] = Field(default=None, max_length=80)


class StaffOut(BaseModel):
    firebase_uid: str
    email: Optional[str] = None
    full_name: str
    role: StaffRole
    status: StaffStatus
    facility: Optional[str] = None
    department: Optional[str] = None
    license_number: Optional[str] = None
    review_note: Optional[str] = None

    class Config:
        from_attributes = True


class ReviewIn(BaseModel):
    note: Optional[str] = Field(default=None, max_length=500)
    role: Optional[StaffRole] = None  # admin may adjust the role on approval


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
        staff.role = StaffRole.ADMIN
        staff.status = StaffStatus.APPROVED
        staff.reviewed_by = "bootstrap"

    db.commit()
    db.refresh(staff)
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
    _: StaffAccount = Depends(require_admin),
    db: Session = Depends(get_db),
):
    q = db.query(StaffAccount)
    if status is not None:
        q = q.filter(StaffAccount.status == status)
    return q.order_by(StaffAccount.created_at.desc()).all()


def _review(db: Session, uid: str, reviewer: StaffAccount, new_status: StaffStatus, payload: ReviewIn):
    staff = db.query(StaffAccount).filter(StaffAccount.firebase_uid == uid).first()
    if staff is None:
        raise HTTPException(status_code=404, detail="Staff request not found")
    if staff.firebase_uid == reviewer.firebase_uid:
        raise HTTPException(status_code=400, detail="You can't review your own account")
    staff.status = new_status
    staff.reviewed_by = reviewer.firebase_uid
    staff.review_note = payload.note
    if payload.role is not None and new_status == StaffStatus.APPROVED:
        staff.role = payload.role
    db.commit()
    db.refresh(staff)
    return staff


@router.post("/admin/staff-requests/{uid}/approve", response_model=StaffOut)
def approve_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.APPROVED, payload)


@router.post("/admin/staff-requests/{uid}/reject", response_model=StaffOut)
def reject_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.REJECTED, payload)


@router.post("/admin/staff-requests/{uid}/suspend", response_model=StaffOut)
def suspend_staff(uid: str, payload: ReviewIn = ReviewIn(), admin: StaffAccount = Depends(require_admin), db: Session = Depends(get_db)):
    return _review(db, uid, admin, StaffStatus.SUSPENDED, payload)
