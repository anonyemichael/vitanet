# app/routes/portal.py
"""Hospital portal API (staff) and the patient side of referrals.

Staff endpoints live under /portal and are scoped to the caller's hospital.
Patient endpoints live under /referrals and /facilities."""
import math
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import (
    CurrentUser,
    current_user_id,
    get_current_user,
    require_staff,
)
from app.models.health_alert import HealthAlert
from app.models.hospital import Hospital
from app.models.portal import (
    AuditLog,
    FacilityRegistration,
    PortalCase,
    PortalEquipment,
    PortalWard,
    Referral,
)
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus
from app.models.user import User

router = APIRouter(tags=["portal"])

LEVELS = {"urgent", "doctor", "pharmacist", "self_care", "routine"}
CASE_STATUSES = {"waiting", "treatment", "discharged"}


# ───────────────────────── helpers ─────────────────────────

def _haversine_km(lat1, lng1, lat2, lng2) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _eta_minutes(km: float) -> int:
    # Urban driving ~25 km/h plus 5 min to get going.
    return int(round(km / 25 * 60)) + 5


def facility_staff(staff: StaffAccount = Depends(require_staff)) -> StaffAccount:
    if staff.hospital_id is None:
        raise HTTPException(status_code=409, detail="Create or join a hospital first")
    return staff


def facility_admin(staff: StaffAccount = Depends(facility_staff)) -> StaffAccount:
    if staff.role != StaffRole.ADMIN:
        raise HTTPException(status_code=403, detail="Hospital administrators only")
    return staff


def _audit(db: Session, staff: StaffAccount, action: str, target: Optional[str] = None, detail: Optional[str] = None):
    db.add(AuditLog(
        hospital_id=staff.hospital_id, actor_uid=staff.firebase_uid, actor_name=staff.full_name,
        action=action, target=target, detail=detail,
    ))


def _event(case: PortalCase, by: str, kind: str, text: str):
    case.timeline = [*(case.timeline or []), {
        "at": datetime.utcnow().isoformat() + "Z", "by": by, "kind": kind, "text": text,
    }]


def _hospital_out(h: Hospital, reg: Optional[FacilityRegistration]) -> Dict[str, Any]:
    return {
        "id": str(h.id), "name": h.name, "address": h.address, "latitude": h.latitude,
        "longitude": h.longitude, "phone_number": h.phone_number,
        "has_emergency_room": bool(h.has_emergency_room), "has_ambulance": bool(h.has_ambulance),
        "ambulance_available": bool(h.ambulance_available),
        "accepting_referrals": bool(reg.accepting_referrals) if reg else False,
    }


def _referral_out(r: Referral, h: Optional[Hospital] = None) -> Dict[str, Any]:
    return {
        "id": str(r.id), "hospital_id": str(r.hospital_id), "hospital_name": h.name if h else None,
        "status": r.status, "triage_level": r.triage_level, "summary": r.summary or {},
        "eta_minutes": r.eta_minutes, "decline_reason": r.decline_reason,
        "case_id": str(r.case_id) if r.case_id else None,
        "created_at": r.created_at.isoformat() + "Z", "updated_at": r.updated_at.isoformat() + "Z",
    }


def _case_out(c: PortalCase, ward_names: Optional[Dict[int, str]] = None) -> Dict[str, Any]:
    return {
        "id": str(c.id), "referral_id": str(c.referral_id) if c.referral_id else None,
        "patient_name": c.patient_name, "age": c.age, "sex": c.sex, "complaint": c.complaint,
        "level": c.level, "status": c.status, "ward_id": c.ward_id,
        "ward_name": (ward_names or {}).get(c.ward_id) if c.ward_id else None, "bed": c.bed,
        "assignee_uid": c.assignee_uid, "assignee_name": c.assignee_name, "allergies": c.allergies,
        "timeline": c.timeline or [], "discharge_summary": c.discharge_summary,
        "created_at": c.created_at.isoformat() + "Z", "updated_at": c.updated_at.isoformat() + "Z",
    }


def _ward_names(db: Session, hospital_id) -> Dict[int, str]:
    return {w.id: w.name for w in db.query(PortalWard).filter(PortalWard.hospital_id == hospital_id)}


def _get_case(db: Session, staff: StaffAccount, case_id: UUID) -> PortalCase:
    c = db.query(PortalCase).filter(PortalCase.id == case_id, PortalCase.hospital_id == staff.hospital_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Case not found")
    return c


def _resolve_assignee(db: Session, staff: StaffAccount, uid: Optional[str]) -> Optional[StaffAccount]:
    if not uid:
        return None
    a = db.query(StaffAccount).filter(
        StaffAccount.firebase_uid == uid, StaffAccount.hospital_id == staff.hospital_id,
        StaffAccount.status == StaffStatus.APPROVED,
    ).first()
    if not a:
        raise HTTPException(status_code=400, detail="Assignee must be approved staff at this hospital")
    return a


def _set_ward(db: Session, staff: StaffAccount, case: PortalCase, ward_id: Optional[int]):
    """Move a case to a ward, keeping bed counts right."""
    if ward_id == case.ward_id:
        return
    if ward_id is not None:
        w = db.query(PortalWard).filter(PortalWard.id == ward_id, PortalWard.hospital_id == staff.hospital_id).first()
        if not w:
            raise HTTPException(status_code=400, detail="Unknown ward")
        if w.beds_occupied >= w.beds_total:
            raise HTTPException(status_code=409, detail=f"{w.name} has no free beds")
        w.beds_occupied += 1
    if case.ward_id is not None:
        old = db.query(PortalWard).filter(PortalWard.id == case.ward_id).first()
        if old and old.beds_occupied > 0:
            old.beds_occupied -= 1
    case.ward_id = ward_id


# ───────────────────────── facility ─────────────────────────

class HospitalIn(BaseModel):
    name: str = Field(..., min_length=2, max_length=200)
    address: Optional[str] = Field(default=None, max_length=300)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    phone_number: Optional[str] = Field(default=None, max_length=40)
    has_emergency_room: bool = True
    has_ambulance: bool = False
    ambulance_available: bool = False
    accepting_referrals: bool = True


@router.post("/portal/hospitals")
def create_hospital(payload: HospitalIn, staff: StaffAccount = Depends(require_staff), db: Session = Depends(get_db)):
    """An approved admin who has no hospital yet creates their facility."""
    if staff.role != StaffRole.ADMIN:
        raise HTTPException(status_code=403, detail="Only an administrator can create a hospital")
    if staff.hospital_id is not None:
        raise HTTPException(status_code=409, detail="You already belong to a hospital")
    h = Hospital(
        name=payload.name.strip(), address=payload.address, latitude=payload.latitude,
        longitude=payload.longitude, phone_number=payload.phone_number,
        has_emergency_room=payload.has_emergency_room, has_ambulance=payload.has_ambulance,
        ambulance_available=payload.ambulance_available,
    )
    db.add(h)
    db.flush()
    reg = FacilityRegistration(hospital_id=h.id, created_by=staff.firebase_uid,
                               accepting_referrals=payload.accepting_referrals)
    db.add(reg)
    staff.hospital_id = h.id
    _audit(db, staff, "facility.create", str(h.id), h.name)
    db.commit()
    return _hospital_out(h, reg)


@router.get("/portal/hospital")
def my_hospital(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    h = db.query(Hospital).filter(Hospital.id == staff.hospital_id).first()
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == staff.hospital_id).first()
    return _hospital_out(h, reg)


@router.put("/portal/hospital")
def update_hospital(payload: HospitalIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    h = db.query(Hospital).filter(Hospital.id == staff.hospital_id).first()
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == staff.hospital_id).first()
    for k in ("name", "address", "latitude", "longitude", "phone_number", "has_emergency_room",
              "has_ambulance", "ambulance_available"):
        setattr(h, k, getattr(payload, k))
    reg.accepting_referrals = payload.accepting_referrals
    _audit(db, staff, "facility.update", str(h.id))
    db.commit()
    return _hospital_out(h, reg)


@router.get("/facilities")
def list_facilities(
    lat: Optional[float] = None, lng: Optional[float] = None, limit: int = 10,
    _: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db),
):
    """Registered hospitals (for staff sign-up and for patients choosing where
    to send a referral), nearest first when a location is given."""
    rows = (db.query(Hospital, FacilityRegistration)
            .join(FacilityRegistration, FacilityRegistration.hospital_id == Hospital.id).all())
    out = []
    for h, reg in rows:
        item = _hospital_out(h, reg)
        if lat is not None and lng is not None:
            km = _haversine_km(lat, lng, h.latitude, h.longitude)
            item["distance_km"] = round(km, 1)
            item["eta_minutes"] = _eta_minutes(km)
        out.append(item)
    if lat is not None and lng is not None:
        out.sort(key=lambda x: x["distance_km"])
    else:
        out.sort(key=lambda x: x["name"].lower())
    return out[: max(1, min(limit, 50))]


# ───────────────────────── patient: referrals ─────────────────────────

class ReferralIn(BaseModel):
    hospital_id: UUID
    consent: bool
    triage_level: str
    complaint: str = Field(..., min_length=2, max_length=300)
    triage_summary: Optional[str] = Field(default=None, max_length=2000)
    patient_name: Optional[str] = Field(default=None, max_length=150)
    age: Optional[int] = Field(default=None, ge=0, le=130)
    sex: Optional[str] = Field(default=None, max_length=16)
    allergies: List[str] = []
    medications: List[str] = []
    conditions: List[str] = []
    vitals: Dict[str, Any] = {}
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)


@router.post("/referrals")
def create_referral(payload: ReferralIn, me: UUID = Depends(current_user_id), db: Session = Depends(get_db)):
    if not payload.consent:
        raise HTTPException(status_code=400, detail="Consent is required to share your summary")
    if payload.triage_level not in LEVELS:
        raise HTTPException(status_code=400, detail="Unknown triage level")
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == payload.hospital_id).first()
    if not reg or not reg.accepting_referrals:
        raise HTTPException(status_code=409, detail="This hospital is not accepting VitaNet referrals")
    open_ref = db.query(Referral).filter(
        Referral.patient_user_id == me, Referral.status.in_(["new", "accepted"])).first()
    if open_ref:
        raise HTTPException(status_code=409, detail="You already have an open referral")
    h = db.query(Hospital).filter(Hospital.id == payload.hospital_id).first()
    user = db.query(User).filter(User.id == me).first()
    eta = None
    if payload.latitude is not None and payload.longitude is not None:
        eta = _eta_minutes(_haversine_km(payload.latitude, payload.longitude, h.latitude, h.longitude))
    summary = {
        "patient_name": payload.patient_name or (user.full_name if user else "VitaNet patient"),
        "age": payload.age, "sex": payload.sex, "complaint": payload.complaint,
        "triage_summary": payload.triage_summary, "allergies": payload.allergies,
        "medications": payload.medications, "conditions": payload.conditions, "vitals": payload.vitals,
    }
    r = Referral(
        hospital_id=payload.hospital_id, patient_user_id=me, status="new",
        triage_level=payload.triage_level, summary=summary, consent_at=datetime.utcnow(),
        patient_lat=payload.latitude, patient_lng=payload.longitude, eta_minutes=eta,
    )
    db.add(r)
    db.commit()
    db.refresh(r)
    return _referral_out(r, h)


@router.get("/referrals/mine")
def my_referrals(me: UUID = Depends(current_user_id), db: Session = Depends(get_db)):
    rows = db.query(Referral).filter(Referral.patient_user_id == me).order_by(Referral.created_at.desc()).limit(20).all()
    hospitals = {h.id: h for h in db.query(Hospital).filter(Hospital.id.in_([r.hospital_id for r in rows]))} if rows else {}
    out = []
    for r in rows:
        item = _referral_out(r, hospitals.get(r.hospital_id))
        if r.case_id:
            c = db.query(PortalCase).filter(PortalCase.id == r.case_id).first()
            if c:
                item["case"] = {"status": c.status, "assignee_name": c.assignee_name,
                                "ward_name": _ward_names(db, c.hospital_id).get(c.ward_id) if c.ward_id else None,
                                "bed": c.bed}
        out.append(item)
    return out


@router.post("/referrals/{referral_id}/cancel")
def cancel_referral(referral_id: UUID, me: UUID = Depends(current_user_id), db: Session = Depends(get_db)):
    r = db.query(Referral).filter(Referral.id == referral_id, Referral.patient_user_id == me).first()
    if not r:
        raise HTTPException(status_code=404, detail="Referral not found")
    if r.status != "new":
        raise HTTPException(status_code=409, detail="This referral can no longer be cancelled")
    r.status = "cancelled"
    db.commit()
    return _referral_out(r)


# ───────────────────────── staff: dashboard ─────────────────────────

@router.get("/portal/dashboard")
def dashboard(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    hid = staff.hospital_id
    cases = db.query(PortalCase).filter(PortalCase.hospital_id == hid)
    wards = db.query(PortalWard).filter(PortalWard.hospital_id == hid).all()
    incoming = (db.query(Referral).filter(Referral.hospital_id == hid, Referral.status == "new")
                .order_by(Referral.created_at.desc()).all())
    names = _ward_names(db, hid)
    mine = (cases.filter(PortalCase.assignee_uid == staff.firebase_uid, PortalCase.status != "discharged")
            .order_by(PortalCase.created_at.desc()).limit(10).all())
    return {
        "counts": {
            "incoming": len(incoming),
            "incoming_urgent": sum(1 for r in incoming if r.triage_level == "urgent"),
            "waiting": cases.filter(PortalCase.status == "waiting").count(),
            "in_treatment": cases.filter(PortalCase.status == "treatment").count(),
            "beds_free": sum(max(w.beds_total - w.beds_occupied, 0) for w in wards),
            "beds_total": sum(w.beds_total for w in wards),
            "staff_on_duty": db.query(StaffAccount).filter(
                StaffAccount.hospital_id == hid, StaffAccount.status == StaffStatus.APPROVED,
                StaffAccount.on_duty.is_(True)).count(),
            "pending_staff": db.query(StaffAccount).filter(
                StaffAccount.hospital_id == hid, StaffAccount.status == StaffStatus.PENDING).count(),
        },
        "incoming": [_referral_out(r) for r in incoming[:10]],
        "my_cases": [_case_out(c, names) for c in mine],
        "me": {"name": staff.full_name, "role": staff.role.value, "on_duty": bool(staff.on_duty)},
    }


# ───────────────────────── staff: referrals ─────────────────────────

class AcceptIn(BaseModel):
    assignee_uid: Optional[str] = None
    ward_id: Optional[int] = None
    bed: Optional[str] = Field(default=None, max_length=40)


class DeclineIn(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500)


@router.get("/portal/referrals")
def list_referrals(status: Optional[str] = Query(default=None), staff: StaffAccount = Depends(facility_staff),
                   db: Session = Depends(get_db)):
    q = db.query(Referral).filter(Referral.hospital_id == staff.hospital_id)
    if status:
        q = q.filter(Referral.status == status)
    return [_referral_out(r) for r in q.order_by(Referral.created_at.desc()).limit(200)]


@router.get("/portal/referrals/{referral_id}")
def get_referral(referral_id: UUID, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    r = db.query(Referral).filter(Referral.id == referral_id, Referral.hospital_id == staff.hospital_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Referral not found")
    return _referral_out(r)


@router.post("/portal/referrals/{referral_id}/accept")
def accept_referral(referral_id: UUID, payload: AcceptIn, staff: StaffAccount = Depends(facility_staff),
                    db: Session = Depends(get_db)):
    r = db.query(Referral).filter(Referral.id == referral_id, Referral.hospital_id == staff.hospital_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Referral not found")
    if r.status != "new":
        raise HTTPException(status_code=409, detail=f"Referral is already {r.status}")
    assignee = _resolve_assignee(db, staff, payload.assignee_uid)
    s = r.summary or {}
    level = r.triage_level if r.triage_level in ("urgent", "doctor") else "routine"
    c = PortalCase(
        hospital_id=staff.hospital_id, referral_id=r.id, patient_user_id=r.patient_user_id,
        patient_name=s.get("patient_name") or "VitaNet patient", age=s.get("age"), sex=s.get("sex"),
        complaint=s.get("complaint") or "VitaNet referral", level=level, status="waiting",
        bed=payload.bed, assignee_uid=assignee.firebase_uid if assignee else None,
        assignee_name=assignee.full_name if assignee else None,
        allergies=", ".join(s.get("allergies") or []) or None, timeline=[],
    )
    db.add(c)
    db.flush()
    _set_ward(db, staff, c, payload.ward_id)
    _event(c, staff.full_name, "referral", f"Accepted VitaNet referral ({r.triage_level})")
    r.status, r.handled_by, r.case_id = "accepted", staff.firebase_uid, c.id
    _audit(db, staff, "referral.accept", str(r.id))
    db.commit()
    return {"referral": _referral_out(r), "case": _case_out(c, _ward_names(db, staff.hospital_id))}


@router.post("/portal/referrals/{referral_id}/decline")
def decline_referral(referral_id: UUID, payload: DeclineIn, staff: StaffAccount = Depends(facility_staff),
                     db: Session = Depends(get_db)):
    r = db.query(Referral).filter(Referral.id == referral_id, Referral.hospital_id == staff.hospital_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Referral not found")
    if r.status != "new":
        raise HTTPException(status_code=409, detail=f"Referral is already {r.status}")
    r.status, r.decline_reason, r.handled_by = "declined", payload.reason, staff.firebase_uid
    _audit(db, staff, "referral.decline", str(r.id), payload.reason)
    db.commit()
    return _referral_out(r)


# ───────────────────────── staff: cases ─────────────────────────

class CaseIn(BaseModel):
    patient_name: str = Field(..., min_length=2, max_length=150)
    age: Optional[int] = Field(default=None, ge=0, le=130)
    sex: Optional[str] = Field(default=None, max_length=16)
    complaint: str = Field(..., min_length=2, max_length=300)
    level: str = "routine"
    ward_id: Optional[int] = None
    bed: Optional[str] = Field(default=None, max_length=40)
    assignee_uid: Optional[str] = None
    allergies: Optional[str] = Field(default=None, max_length=300)


class CaseUpdateIn(BaseModel):
    status: Optional[str] = None
    ward_id: Optional[int] = None
    clear_ward: bool = False
    bed: Optional[str] = Field(default=None, max_length=40)
    assignee_uid: Optional[str] = None
    level: Optional[str] = None


class NoteIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000)


class DischargeIn(BaseModel):
    summary: str = Field(..., min_length=3, max_length=8000)


@router.get("/portal/cases")
def list_cases(status: Optional[str] = None, mine: bool = False, staff: StaffAccount = Depends(facility_staff),
               db: Session = Depends(get_db)):
    q = db.query(PortalCase).filter(PortalCase.hospital_id == staff.hospital_id)
    if status:
        q = q.filter(PortalCase.status == status)
    if mine:
        q = q.filter(PortalCase.assignee_uid == staff.firebase_uid)
    names = _ward_names(db, staff.hospital_id)
    return [_case_out(c, names) for c in q.order_by(PortalCase.created_at.desc()).limit(300)]


@router.post("/portal/cases")
def create_case(payload: CaseIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    if payload.level not in ("urgent", "doctor", "routine"):
        raise HTTPException(status_code=400, detail="Level must be urgent, doctor or routine")
    assignee = _resolve_assignee(db, staff, payload.assignee_uid)
    c = PortalCase(
        hospital_id=staff.hospital_id, patient_name=payload.patient_name.strip(), age=payload.age,
        sex=payload.sex, complaint=payload.complaint, level=payload.level, status="waiting",
        bed=payload.bed, allergies=payload.allergies, timeline=[],
        assignee_uid=assignee.firebase_uid if assignee else None,
        assignee_name=assignee.full_name if assignee else None,
    )
    db.add(c)
    db.flush()
    _set_ward(db, staff, c, payload.ward_id)
    _event(c, staff.full_name, "created", "Walk-in case created")
    _audit(db, staff, "case.create", str(c.id))
    db.commit()
    return _case_out(c, _ward_names(db, staff.hospital_id))


@router.get("/portal/cases/{case_id}")
def get_case(case_id: UUID, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    out = _case_out(c, _ward_names(db, staff.hospital_id))
    if c.referral_id:
        r = db.query(Referral).filter(Referral.id == c.referral_id).first()
        out["referral"] = _referral_out(r) if r else None
    return out


@router.patch("/portal/cases/{case_id}")
def update_case(case_id: UUID, payload: CaseUpdateIn, staff: StaffAccount = Depends(facility_staff),
                db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Case is discharged")
    if payload.status is not None:
        if payload.status not in ("waiting", "treatment"):
            raise HTTPException(status_code=400, detail="Use discharge to close a case")
        if payload.status != c.status:
            _event(c, staff.full_name, "status", f"Status: {c.status} → {payload.status}")
            c.status = payload.status
    if payload.level is not None:
        if payload.level not in ("urgent", "doctor", "routine"):
            raise HTTPException(status_code=400, detail="Level must be urgent, doctor or routine")
        c.level = payload.level
    if payload.clear_ward:
        _set_ward(db, staff, c, None)
        _event(c, staff.full_name, "move", "Removed from ward")
    elif payload.ward_id is not None and payload.ward_id != c.ward_id:
        _set_ward(db, staff, c, payload.ward_id)
        _event(c, staff.full_name, "move", f"Moved to {_ward_names(db, staff.hospital_id).get(payload.ward_id)}")
    if payload.bed is not None:
        c.bed = payload.bed or None
    if payload.assignee_uid is not None:
        a = _resolve_assignee(db, staff, payload.assignee_uid) if payload.assignee_uid else None
        c.assignee_uid = a.firebase_uid if a else None
        c.assignee_name = a.full_name if a else None
        _event(c, staff.full_name, "assign", f"Assigned to {a.full_name}" if a else "Unassigned")
    _audit(db, staff, "case.update", str(c.id))
    db.commit()
    return _case_out(c, _ward_names(db, staff.hospital_id))


@router.post("/portal/cases/{case_id}/notes")
def add_note(case_id: UUID, payload: NoteIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    _event(c, staff.full_name, "note", payload.text)
    _audit(db, staff, "case.note", str(c.id))
    db.commit()
    return _case_out(c, _ward_names(db, staff.hospital_id))


@router.post("/portal/cases/{case_id}/discharge")
def discharge_case(case_id: UUID, payload: DischargeIn, staff: StaffAccount = Depends(facility_staff),
                   db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Case is already discharged")
    _set_ward(db, staff, c, None)
    c.status, c.discharge_summary = "discharged", payload.summary
    _event(c, staff.full_name, "discharge", "Discharged")
    if c.referral_id:
        r = db.query(Referral).filter(Referral.id == c.referral_id).first()
        if r:
            r.status = "arrived"  # referral completed
    _audit(db, staff, "case.discharge", str(c.id))
    db.commit()
    return _case_out(c, _ward_names(db, staff.hospital_id))


# ───────────────────────── staff: alerts ─────────────────────────

@router.get("/portal/alerts")
def portal_alerts(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """Real alerts only: new urgent referrals, plus vitals alerts for patients
    who have an open referral/case with this hospital (they consented)."""
    hid = staff.hospital_id
    out: List[Dict[str, Any]] = []
    for r in db.query(Referral).filter(Referral.hospital_id == hid, Referral.status == "new",
                                       Referral.triage_level == "urgent"):
        s = r.summary or {}
        out.append({"id": f"ref-{r.id}", "kind": "referral", "severity": "critical",
                    "title": f"Urgent referral · {s.get('patient_name', 'Patient')}",
                    "body": s.get("complaint"), "referral_id": str(r.id),
                    "at": r.created_at.isoformat() + "Z"})
    patient_ids = [r.patient_user_id for r in db.query(Referral).filter(
        Referral.hospital_id == hid, Referral.status.in_(["new", "accepted"]))]
    if patient_ids:
        for a in (db.query(HealthAlert).filter(HealthAlert.user_id.in_(patient_ids))
                  .order_by(HealthAlert.created_at.desc()).limit(50)):
            out.append({"id": f"vit-{a.id}", "kind": "vitals",
                        "severity": "critical" if getattr(a.severity, "value", a.severity) == "urgent" else "warning",
                        "title": f"{getattr(a, 'vital_type', 'Vital')} alert",
                        "body": getattr(a, "message", None), "patient_user_id": str(a.user_id),
                        "at": a.created_at.isoformat() + "Z"})
    out.sort(key=lambda x: x["at"], reverse=True)
    return out


# ───────────────────────── staff: capacity & team ─────────────────────────

class WardIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    beds_total: int = Field(..., ge=0, le=5000)
    beds_occupied: int = Field(default=0, ge=0, le=5000)
    critical: bool = False


class EquipmentIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    available: int = Field(..., ge=0, le=100000)
    total: int = Field(..., ge=0, le=100000)
    note: Optional[str] = Field(default=None, max_length=200)


class DutyIn(BaseModel):
    on_duty: bool


def _staff_out(s: StaffAccount) -> Dict[str, Any]:
    return {"firebase_uid": s.firebase_uid, "full_name": s.full_name, "email": s.email,
            "role": s.role.value, "status": s.status.value, "on_duty": bool(s.on_duty),
            "department": s.department, "license_number": s.license_number}


@router.get("/portal/capacity")
def capacity(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    hid = staff.hospital_id
    return {
        "wards": [{"id": w.id, "name": w.name, "beds_total": w.beds_total, "beds_occupied": w.beds_occupied,
                   "critical": w.critical} for w in db.query(PortalWard).filter(PortalWard.hospital_id == hid)],
        "equipment": [{"id": e.id, "name": e.name, "available": e.available, "total": e.total, "note": e.note}
                      for e in db.query(PortalEquipment).filter(PortalEquipment.hospital_id == hid)],
        "team": [_staff_out(s) for s in db.query(StaffAccount).filter(
            StaffAccount.hospital_id == hid, StaffAccount.status == StaffStatus.APPROVED)],
    }


def _check_beds(total: int, occupied: int):
    if occupied > total:
        raise HTTPException(status_code=400, detail="Occupied beds can't exceed total beds")


@router.post("/portal/wards")
def add_ward(payload: WardIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    _check_beds(payload.beds_total, payload.beds_occupied)
    w = PortalWard(hospital_id=staff.hospital_id, **payload.model_dump())
    db.add(w)
    _audit(db, staff, "ward.create", payload.name)
    db.commit()
    return {"id": w.id, **payload.model_dump()}


@router.put("/portal/wards/{ward_id}")
def update_ward(ward_id: int, payload: WardIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """Nurses/doctors may update bed occupancy; only admins rename or resize."""
    w = db.query(PortalWard).filter(PortalWard.id == ward_id, PortalWard.hospital_id == staff.hospital_id).first()
    if not w:
        raise HTTPException(status_code=404, detail="Ward not found")
    _check_beds(payload.beds_total, payload.beds_occupied)
    if staff.role != StaffRole.ADMIN and (payload.name != w.name or payload.beds_total != w.beds_total
                                          or payload.critical != w.critical):
        raise HTTPException(status_code=403, detail="Only administrators can change ward details")
    for k, v in payload.model_dump().items():
        setattr(w, k, v)
    _audit(db, staff, "ward.update", w.name, f"{w.beds_occupied}/{w.beds_total}")
    db.commit()
    return {"id": w.id, **payload.model_dump()}


@router.delete("/portal/wards/{ward_id}", status_code=204)
def delete_ward(ward_id: int, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    w = db.query(PortalWard).filter(PortalWard.id == ward_id, PortalWard.hospital_id == staff.hospital_id).first()
    if not w:
        raise HTTPException(status_code=404, detail="Ward not found")
    if db.query(PortalCase).filter(PortalCase.ward_id == ward_id, PortalCase.status != "discharged").count():
        raise HTTPException(status_code=409, detail="Move patients out of this ward first")
    db.delete(w)
    _audit(db, staff, "ward.delete", w.name)
    db.commit()


@router.post("/portal/equipment")
def add_equipment(payload: EquipmentIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    if payload.available > payload.total:
        raise HTTPException(status_code=400, detail="Available can't exceed total")
    e = PortalEquipment(hospital_id=staff.hospital_id, **payload.model_dump())
    db.add(e)
    _audit(db, staff, "equipment.create", payload.name)
    db.commit()
    return {"id": e.id, **payload.model_dump()}


@router.put("/portal/equipment/{equipment_id}")
def update_equipment(equipment_id: int, payload: EquipmentIn, staff: StaffAccount = Depends(facility_staff),
                     db: Session = Depends(get_db)):
    e = db.query(PortalEquipment).filter(PortalEquipment.id == equipment_id,
                                         PortalEquipment.hospital_id == staff.hospital_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Equipment not found")
    if payload.available > payload.total:
        raise HTTPException(status_code=400, detail="Available can't exceed total")
    if staff.role != StaffRole.ADMIN and (payload.name != e.name or payload.total != e.total):
        raise HTTPException(status_code=403, detail="Only administrators can change equipment details")
    for k, v in payload.model_dump().items():
        setattr(e, k, v)
    _audit(db, staff, "equipment.update", e.name, f"{e.available}/{e.total}")
    db.commit()
    return {"id": e.id, **payload.model_dump()}


@router.delete("/portal/equipment/{equipment_id}", status_code=204)
def delete_equipment(equipment_id: int, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    e = db.query(PortalEquipment).filter(PortalEquipment.id == equipment_id,
                                         PortalEquipment.hospital_id == staff.hospital_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Equipment not found")
    db.delete(e)
    _audit(db, staff, "equipment.delete", e.name)
    db.commit()


@router.put("/portal/me/duty")
def set_duty(payload: DutyIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    staff.on_duty = payload.on_duty
    _audit(db, staff, "duty.on" if payload.on_duty else "duty.off")
    db.commit()
    return _staff_out(staff)


@router.get("/portal/team")
def team(staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    """Everyone linked to this hospital, including pending/rejected/suspended."""
    rows = db.query(StaffAccount).filter(StaffAccount.hospital_id == staff.hospital_id).order_by(StaffAccount.created_at.desc())
    return [_staff_out(s) for s in rows]


@router.get("/portal/audit")
def audit_log(limit: int = 100, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    rows = (db.query(AuditLog).filter(AuditLog.hospital_id == staff.hospital_id)
            .order_by(AuditLog.at.desc()).limit(max(1, min(limit, 500))))
    return [{"at": a.at.isoformat() + "Z", "actor": a.actor_name, "action": a.action, "target": a.target,
             "detail": a.detail} for a in rows]
