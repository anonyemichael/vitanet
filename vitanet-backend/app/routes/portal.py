# app/routes/portal.py
"""Hospital portal API (staff) and the patient side of referrals.

Staff endpoints live under /portal and are scoped to the caller's hospital.
Patient endpoints live under /referrals and /facilities.

Lifecycle
  referral: new → accepted → arrived → closed   (or declined / cancelled)
  case:     expected → waiting → treatment → discharged
A referral accepted here creates a case in `expected` (bed reserved). Marking
the patient arrived moves it to `waiting`; discharge closes both.
Every write publishes a small event to open portals (see portal_events)."""
import math
from datetime import datetime, timedelta
from typing import Any, Dict, Iterable, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import CurrentUser, current_user_id, get_current_user, require_staff
from app.models.health_alert import HealthAlert
from app.models.hospital import Hospital
from app.models.portal import (
    AuditLog,
    FacilityRegistration,
    PortalAlertAck,
    PortalBroadcast,
    PortalCase,
    PortalCaseVitals,
    PortalEquipment,
    PortalWard,
    Referral,
)
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus
from app.services import portal_rules
from app.services.portal_events import hub

router = APIRouter(tags=["portal"])

LEVELS = {"urgent", "doctor", "pharmacist", "self_care", "routine"}
CASE_LEVELS = ("urgent", "doctor", "routine")
OPEN_REFERRAL = ("new", "accepted")
ACTIVE_CASE = ("expected", "waiting", "treatment")
OUTCOMES = ("home", "admitted", "transferred", "left")
SEVERITIES = ("critical", "warning", "info")


# ───────────────────────── helpers ─────────────────────────

def _iso(dt: Optional[datetime]) -> Optional[str]:
    return dt.isoformat() + "Z" if dt else None


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


def _event(case: PortalCase, by: str, kind: str, text: str, data: Optional[Dict[str, Any]] = None):
    entry = {"at": _iso(datetime.utcnow()), "by": by, "kind": kind, "text": text}
    if data:
        entry["data"] = data
    case.timeline = [*(case.timeline or []), entry]


def _hospital_out(h: Hospital, reg: Optional[FacilityRegistration], db: Optional[Session] = None) -> Dict[str, Any]:
    res = {
        "id": str(h.id), "name": h.name, "address": h.address, "latitude": h.latitude,
        "longitude": h.longitude, "phone_number": h.phone_number,
        "has_emergency_room": bool(h.has_emergency_room), "has_ambulance": bool(h.has_ambulance),
        "ambulance_available": bool(h.ambulance_available),
        "accepting_referrals": bool(reg.accepting_referrals) if reg else False,
    }
    if db is not None:
        wards = db.query(PortalWard).filter(PortalWard.hospital_id == h.id).all()
        res["beds_total"] = sum(w.beds_total for w in wards)
        res["beds_free"] = sum(max(w.beds_total - w.beds_occupied, 0) for w in wards)
    return res


def _referral_out(r: Referral, h: Optional[Hospital] = None) -> Dict[str, Any]:
    eta_at = r.created_at + timedelta(minutes=r.eta_minutes) if r.eta_minutes is not None else None
    return {
        "id": str(r.id), "hospital_id": str(r.hospital_id), "hospital_name": h.name if h else None,
        "hospital_phone": h.phone_number if h else None,
        "hospital_latitude": h.latitude if h else None,
        "hospital_longitude": h.longitude if h else None,
        "status": r.status, "triage_level": r.triage_level, "source": r.source or "app",
        "summary": r.summary or {}, "eta_minutes": r.eta_minutes, "eta_at": _iso(eta_at),
        "decline_reason": r.decline_reason, "case_id": str(r.case_id) if r.case_id else None,
        "arrived_at": _iso(r.arrived_at),
        "created_at": _iso(r.created_at), "updated_at": _iso(r.updated_at),
    }


def _vitals_out(v: Optional[PortalCaseVitals]) -> Optional[Dict[str, Any]]:
    if v is None:
        return None
    return {
        "heart_rate": v.heart_rate, "bp_systolic": v.bp_systolic, "bp_diastolic": v.bp_diastolic,
        "spo2": v.spo2, "temperature": v.temperature, "respiratory_rate": v.respiratory_rate,
        "pain": v.pain, "alert": v.alert, "early_warning": v.early_warning,
        "recorded_by": v.recorded_by, "at": _iso(v.at),
    }


def _latest_vitals(db: Session, case_ids: Iterable[UUID]) -> Dict[UUID, PortalCaseVitals]:
    ids = list(case_ids)
    if not ids:
        return {}
    out: Dict[UUID, PortalCaseVitals] = {}
    for v in (db.query(PortalCaseVitals).filter(PortalCaseVitals.case_id.in_(ids))
              .order_by(PortalCaseVitals.at.desc(), PortalCaseVitals.id.desc())):
        out.setdefault(v.case_id, v)
    return out


def _case_out(c: PortalCase, ward_names: Optional[Dict[int, str]] = None,
              latest: Optional[PortalCaseVitals] = None) -> Dict[str, Any]:
    return {
        "id": str(c.id), "referral_id": str(c.referral_id) if c.referral_id else None,
        "patient_name": c.patient_name, "age": c.age, "sex": c.sex, "complaint": c.complaint,
        "level": c.level, "status": c.status, "ward_id": c.ward_id,
        "ward_name": (ward_names or {}).get(c.ward_id) if c.ward_id else None, "bed": c.bed,
        "assignee_uid": c.assignee_uid, "assignee_name": c.assignee_name, "allergies": c.allergies,
        "timeline": c.timeline or [], "discharge_summary": c.discharge_summary, "outcome": c.outcome,
        "arrived_at": _iso(c.arrived_at), "latest_vitals": _vitals_out(latest),
        "created_at": _iso(c.created_at), "updated_at": _iso(c.updated_at),
    }


def _ward_names(db: Session, hospital_id) -> Dict[int, str]:
    return {w.id: w.name for w in db.query(PortalWard).filter(PortalWard.hospital_id == hospital_id)}


def _case_full(db: Session, c: PortalCase) -> Dict[str, Any]:
    return _case_out(c, _ward_names(db, c.hospital_id), _latest_vitals(db, [c.id]).get(c.id))


def _get_case(db: Session, staff: StaffAccount, case_id: UUID) -> PortalCase:
    c = db.query(PortalCase).filter(PortalCase.id == case_id, PortalCase.hospital_id == staff.hospital_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Case not found")
    return c


def _get_referral(db: Session, staff: StaffAccount, referral_id: UUID) -> Referral:
    r = db.query(Referral).filter(Referral.id == referral_id, Referral.hospital_id == staff.hospital_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Referral not found")
    return r


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


def _mark_arrived(db: Session, staff: StaffAccount, c: PortalCase):
    now = datetime.utcnow()
    c.status, c.arrived_at = "waiting", now
    _event(c, staff.full_name, "arrived", "Arrived at the hospital")
    if c.referral_id:
        r = db.query(Referral).filter(Referral.id == c.referral_id).first()
        if r and r.status == "accepted":
            r.status, r.arrived_at = "arrived", now


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


class AcceptingIn(BaseModel):
    accepting_referrals: bool


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
    return _hospital_out(h, reg, db)


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
    hub.publish(staff.hospital_id, "capacity")
    return _hospital_out(h, reg, db)


@router.put("/portal/hospital/accepting")
def set_accepting(payload: AcceptingIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    """The Accepting / Paused switch on the Board and Hospital screens."""
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == staff.hospital_id).first()
    reg.accepting_referrals = payload.accepting_referrals
    _audit(db, staff, "facility.accepting" if payload.accepting_referrals else "facility.paused")
    db.commit()
    hub.publish(staff.hospital_id, "capacity")
    h = db.query(Hospital).filter(Hospital.id == staff.hospital_id).first()
    return _hospital_out(h, reg, db)


@router.get("/facilities")
def list_facilities(
    lat: Optional[float] = None, lng: Optional[float] = None, limit: int = 10,
    q: Optional[str] = Query(default=None, max_length=100),
    emergency_only: bool = False,
    _: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db),
):
    """Registered hospitals (for staff sign-up and for patients choosing where
    to send a referral), nearest first when a location is given. `q` filters
    by name or address."""
    query = (db.query(Hospital, FacilityRegistration)
             .join(FacilityRegistration, FacilityRegistration.hospital_id == Hospital.id))
    if emergency_only:
        query = query.filter(Hospital.has_emergency_room.is_(True))
    if q and q.strip():
        like = f"%{q.strip()}%"
        query = query.filter(Hospital.name.ilike(like) | Hospital.address.ilike(like))
    out = []
    for h, reg in query.all():
        item = _hospital_out(h, reg, db)
        if lat is not None and lng is not None:
            km = _haversine_km(lat, lng, h.latitude, h.longitude)
            item["distance_km"] = round(km, 1)
            item["eta_minutes"] = _eta_minutes(km)
        out.append(item)
    if lat is not None and lng is not None:
        out.sort(key=lambda x: x["distance_km"])
    else:
        out.sort(key=lambda x: x["name"].lower())
    return out[: max(1, min(limit, 200))]


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
    source: str = Field(default="app", pattern="^(app|checkin)$")
    replace_open: bool = False  # cancel my unanswered referral and send this one instead


def _create_referral(db: Session, me: UUID, payload: ReferralIn) -> Dict[str, Any]:
    if not payload.consent:
        raise HTTPException(status_code=400, detail="Consent is required to share your summary")
    if payload.triage_level not in LEVELS:
        raise HTTPException(status_code=400, detail="Unknown triage level")
    h = db.query(Hospital).filter(Hospital.id == payload.hospital_id).first()
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == payload.hospital_id).first()
    if not h or not reg or not reg.accepting_referrals:
        raise HTTPException(status_code=409, detail="This hospital is not accepting VitaNet patients right now")
    for open_ref in db.query(Referral).filter(Referral.patient_user_id == me, Referral.status.in_(OPEN_REFERRAL)):
        if open_ref.status == "new" and payload.replace_open:
            open_ref.status = "cancelled"
            hub.publish(open_ref.hospital_id, "referral", open_ref.id)
        else:
            raise HTTPException(status_code=409, detail="You already have an open referral")
    eta = None
    if payload.latitude is not None and payload.longitude is not None:
        eta = _eta_minutes(_haversine_km(payload.latitude, payload.longitude, h.latitude, h.longitude))
    summary = {
        # Only what the patient chose to share — never fill in the account name.
        "patient_name": (payload.patient_name or "").strip() or "Name not shared",
        "age": payload.age, "sex": payload.sex, "complaint": payload.complaint,
        "triage_summary": payload.triage_summary, "allergies": payload.allergies,
        "medications": payload.medications, "conditions": payload.conditions, "vitals": payload.vitals,
    }
    r = Referral(
        hospital_id=payload.hospital_id, patient_user_id=me, status="new", source=payload.source,
        triage_level=payload.triage_level, summary=summary, consent_at=datetime.utcnow(),
        patient_lat=payload.latitude, patient_lng=payload.longitude, eta_minutes=eta,
    )
    db.add(r)
    db.commit()
    db.refresh(r)
    hub.publish(r.hospital_id, "referral", r.id)
    if r.triage_level == "urgent":
        hub.publish(r.hospital_id, "alert", r.id)
    return _referral_out(r, h)


@router.post("/referrals")
def create_referral(payload: ReferralIn, me: UUID = Depends(current_user_id), db: Session = Depends(get_db)):
    return _create_referral(db, me, payload)


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
                                "bed": c.bed, "outcome": c.outcome}
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
    hub.publish(r.hospital_id, "referral", r.id)
    return _referral_out(r, db.query(Hospital).filter(Hospital.id == r.hospital_id).first())


class EmergencyCheckinIn(BaseModel):
    complaint: str = Field(..., min_length=2, max_length=300)
    vitals: Optional[Dict[str, Any]] = None
    patient_lat: Optional[float] = Field(default=None, ge=-90, le=90)
    patient_lng: Optional[float] = Field(default=None, ge=-180, le=180)


@router.post("/facilities/{hospital_id}/emergency-checkin")
def emergency_checkin(hospital_id: UUID, payload: EmergencyCheckinIn, me: UUID = Depends(current_user_id),
                      db: Session = Depends(get_db)):
    """Kept for older app builds: the patient tapped "check in" for this
    hospital themselves. Same rules as POST /referrals, urgent, no name."""
    return _create_referral(db, me, ReferralIn(
        hospital_id=hospital_id, consent=True, triage_level="urgent", complaint=payload.complaint,
        vitals=payload.vitals or {}, latitude=payload.patient_lat, longitude=payload.patient_lng,
        source="checkin", replace_open=True,
    ))


@router.get("/patient/cases")
def list_patient_cases(me: UUID = Depends(current_user_id), db: Session = Depends(get_db)):
    """The signed-in patient's hospital visits and discharge summaries."""
    ref_case_ids = [r.case_id for r in db.query(Referral).filter(Referral.patient_user_id == me) if r.case_id]
    cond = PortalCase.patient_user_id == me
    if ref_case_ids:
        cond = cond | PortalCase.id.in_(ref_case_ids)
    cases = db.query(PortalCase).filter(cond).order_by(PortalCase.created_at.desc()).limit(50).all()
    if not cases:
        return []
    hospitals = {h.id: h for h in db.query(Hospital).filter(Hospital.id.in_({c.hospital_id for c in cases}))}
    out = []
    for c in cases:
        h = hospitals.get(c.hospital_id)
        item = _case_out(c, _ward_names(db, c.hospital_id))
        item.pop("assignee_uid", None)
        item["hospital_name"] = h.name if h else "Hospital"
        item["hospital_phone"] = h.phone_number if h else None
        item["hospital_address"] = h.address if h else None
        out.append(item)
    return out


# ───────────────────────── staff: dashboard ─────────────────────────

@router.get("/portal/dashboard")
def dashboard(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    hid = staff.hospital_id
    cases = db.query(PortalCase).filter(PortalCase.hospital_id == hid)
    wards = db.query(PortalWard).filter(PortalWard.hospital_id == hid).all()
    incoming = (db.query(Referral).filter(Referral.hospital_id == hid, Referral.status == "new")
                .order_by(Referral.created_at.desc()).all())
    names = _ward_names(db, hid)
    mine = (cases.filter(PortalCase.assignee_uid == staff.firebase_uid, PortalCase.status.in_(ACTIVE_CASE))
            .order_by(PortalCase.created_at.desc()).limit(20).all())
    reg = db.query(FacilityRegistration).filter(FacilityRegistration.hospital_id == hid).first()
    return {
        "counts": {
            "incoming": len(incoming),
            "incoming_urgent": sum(1 for r in incoming if r.triage_level == "urgent"),
            "expected": cases.filter(PortalCase.status == "expected").count(),
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
        "accepting_referrals": bool(reg.accepting_referrals) if reg else False,
        "incoming": [_referral_out(r) for r in incoming[:20]],
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
        q = q.filter(Referral.status.in_([s.strip() for s in status.split(",") if s.strip()]))
    return [_referral_out(r) for r in q.order_by(Referral.created_at.desc()).limit(200)]


@router.get("/portal/referrals/{referral_id}")
def get_referral(referral_id: UUID, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    r = _get_referral(db, staff, referral_id)
    out = _referral_out(r)
    if r.status == "new":
        ward = portal_rules.suggest_ward(db, staff.hospital_id, r.triage_level)
        who = portal_rules.suggest_assignee(db, staff.hospital_id, r.triage_level)
        out["suggestion"] = {
            "ward_id": ward.id if ward else None, "ward_name": ward.name if ward else None,
            "assignee_uid": who.firebase_uid if who else None, "assignee_name": who.full_name if who else None,
        }
    return out


@router.post("/portal/referrals/{referral_id}/accept")
def accept_referral(referral_id: UUID, payload: AcceptIn, staff: StaffAccount = Depends(facility_staff),
                    db: Session = Depends(get_db)):
    r = _get_referral(db, staff, referral_id)
    if r.status != "new":
        raise HTTPException(status_code=409, detail=f"Referral is already {r.status}")
    assignee = _resolve_assignee(db, staff, payload.assignee_uid)
    s = r.summary or {}
    c = PortalCase(
        hospital_id=staff.hospital_id, referral_id=r.id, patient_user_id=r.patient_user_id,
        patient_name=s.get("patient_name") or "VitaNet patient", age=s.get("age"), sex=s.get("sex"),
        complaint=s.get("complaint") or "VitaNet referral",
        level=r.triage_level if r.triage_level in ("urgent", "doctor") else "routine", status="expected",
        bed=payload.bed, assignee_uid=assignee.firebase_uid if assignee else None,
        assignee_name=assignee.full_name if assignee else None,
        allergies=", ".join(s.get("allergies") or []) or None, timeline=[],
    )
    db.add(c)
    db.flush()
    _set_ward(db, staff, c, payload.ward_id)
    _event(c, "Shared by the patient", "referral", f"Referral from VitaNet: {c.complaint}")
    where = _ward_names(db, staff.hospital_id).get(c.ward_id) if c.ward_id else None
    detail = ", ".join(x for x in [where, c.bed] if x)
    _event(c, staff.full_name, "accepted",
           "Accepted" + (f" · {detail}" if detail else "") + (f". Assigned to {c.assignee_name}." if c.assignee_name else ""))
    r.status, r.handled_by, r.case_id = "accepted", staff.firebase_uid, c.id
    _audit(db, staff, "referral.accept", str(r.id))
    db.commit()
    hub.publish(staff.hospital_id, "referral", r.id)
    hub.publish(staff.hospital_id, "case", c.id)
    hub.publish(staff.hospital_id, "capacity")
    return {"referral": _referral_out(r), "case": _case_full(db, c)}


@router.post("/portal/referrals/{referral_id}/decline")
def decline_referral(referral_id: UUID, payload: DeclineIn, staff: StaffAccount = Depends(facility_staff),
                     db: Session = Depends(get_db)):
    r = _get_referral(db, staff, referral_id)
    if r.status != "new":
        raise HTTPException(status_code=409, detail=f"Referral is already {r.status}")
    r.status, r.decline_reason, r.handled_by = "declined", payload.reason, staff.firebase_uid
    _audit(db, staff, "referral.decline", str(r.id), payload.reason)
    db.commit()
    hub.publish(staff.hospital_id, "referral", r.id)
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
    outcome: str = "home"


@router.get("/portal/cases")
def list_cases(status: Optional[str] = None, mine: bool = False, q: Optional[str] = Query(default=None, max_length=100),
               staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """`status` may be a comma list (e.g. waiting,treatment). `q` searches
    name, complaint and the short case number."""
    query = db.query(PortalCase).filter(PortalCase.hospital_id == staff.hospital_id)
    if status:
        query = query.filter(PortalCase.status.in_([s.strip() for s in status.split(",") if s.strip()]))
    if mine:
        query = query.filter(PortalCase.assignee_uid == staff.firebase_uid)
    rows = query.order_by(PortalCase.created_at.desc()).limit(300).all()
    if q and q.strip():
        needle = q.strip().lower().removeprefix("c-")
        rows = [c for c in rows if needle in c.patient_name.lower() or needle in c.complaint.lower()
                or str(c.id).replace("-", "").lower().startswith(needle)]
    names = _ward_names(db, staff.hospital_id)
    latest = _latest_vitals(db, [c.id for c in rows if c.status != "discharged"])
    return [_case_out(c, names, latest.get(c.id)) for c in rows]


@router.post("/portal/cases")
def create_case(payload: CaseIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """A walk-in: the patient is already here, so the case starts as waiting."""
    if payload.level not in CASE_LEVELS:
        raise HTTPException(status_code=400, detail="Level must be urgent, doctor or routine")
    assignee = _resolve_assignee(db, staff, payload.assignee_uid)
    c = PortalCase(
        hospital_id=staff.hospital_id, patient_name=payload.patient_name.strip(), age=payload.age,
        sex=payload.sex, complaint=payload.complaint, level=payload.level, status="waiting",
        arrived_at=datetime.utcnow(), bed=payload.bed, allergies=payload.allergies, timeline=[],
        assignee_uid=assignee.firebase_uid if assignee else None,
        assignee_name=assignee.full_name if assignee else None,
    )
    db.add(c)
    db.flush()
    _set_ward(db, staff, c, payload.ward_id)
    _event(c, staff.full_name, "created", "Walk-in registered")
    _audit(db, staff, "case.create", str(c.id))
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    if c.ward_id:
        hub.publish(staff.hospital_id, "capacity")
    return _case_full(db, c)


@router.get("/portal/cases/{case_id}")
def get_case(case_id: UUID, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    out = _case_full(db, c)
    out["vitals_history"] = [_vitals_out(v) for v in db.query(PortalCaseVitals).filter(
        PortalCaseVitals.case_id == c.id).order_by(PortalCaseVitals.at.desc(), PortalCaseVitals.id.desc()).limit(30)]
    if c.referral_id:
        r = db.query(Referral).filter(Referral.id == c.referral_id).first()
        out["referral"] = _referral_out(r) if r else None
    return out


@router.post("/portal/cases/{case_id}/arrived")
def mark_arrived(case_id: UUID, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status != "expected":
        raise HTTPException(status_code=409, detail="This patient is already here")
    _mark_arrived(db, staff, c)
    _audit(db, staff, "case.arrived", str(c.id))
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    if c.referral_id:
        hub.publish(staff.hospital_id, "referral", c.referral_id)
    return _case_full(db, c)


@router.patch("/portal/cases/{case_id}")
def update_case(case_id: UUID, payload: CaseUpdateIn, staff: StaffAccount = Depends(facility_staff),
                db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Case is discharged")
    capacity_changed = False
    if payload.status is not None:
        if payload.status not in ("waiting", "treatment"):
            raise HTTPException(status_code=400, detail="Use arrived or discharge for those steps")
        if c.status == "expected":
            _mark_arrived(db, staff, c)
        if payload.status != c.status:
            _event(c, staff.full_name, "status",
                   "Treatment started" if payload.status == "treatment" else "Back to waiting")
            c.status = payload.status
    if payload.level is not None:
        if payload.level not in CASE_LEVELS:
            raise HTTPException(status_code=400, detail="Level must be urgent, doctor or routine")
        if payload.level != c.level:
            _event(c, staff.full_name, "level", f"Triage level changed to {payload.level}")
            c.level = payload.level
    if payload.clear_ward:
        if c.ward_id is not None:
            _set_ward(db, staff, c, None)
            _event(c, staff.full_name, "move", "Removed from ward")
            capacity_changed = True
    elif payload.ward_id is not None and payload.ward_id != c.ward_id:
        _set_ward(db, staff, c, payload.ward_id)
        _event(c, staff.full_name, "move", f"Moved to {_ward_names(db, staff.hospital_id).get(payload.ward_id)}"
               + (f", {payload.bed}" if payload.bed else ""))
        capacity_changed = True
    if payload.bed is not None:
        c.bed = payload.bed or None
    if payload.assignee_uid is not None:
        a = _resolve_assignee(db, staff, payload.assignee_uid) if payload.assignee_uid else None
        c.assignee_uid = a.firebase_uid if a else None
        c.assignee_name = a.full_name if a else None
        _event(c, staff.full_name, "assign", f"Assigned to {a.full_name}" if a else "Unassigned")
    _audit(db, staff, "case.update", str(c.id))
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    if capacity_changed:
        hub.publish(staff.hospital_id, "capacity")
    return _case_full(db, c)


@router.post("/portal/cases/{case_id}/notes")
def add_note(case_id: UUID, payload: NoteIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    _event(c, staff.full_name, "note", payload.text.strip())
    _audit(db, staff, "case.note", str(c.id))
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    return _case_full(db, c)


class PrescriptionIn(BaseModel):
    drug_name: Optional[str] = Field(default=None, max_length=150)
    medication: Optional[str] = Field(default=None, max_length=150)
    dosage: str = Field(..., min_length=1, max_length=60)
    frequency: str = Field(..., min_length=1, max_length=60)
    duration: str = Field(..., min_length=1, max_length=60)
    instructions: Optional[str] = Field(default=None, max_length=300)

    @property
    def resolved_name(self) -> str:
        return self.drug_name or self.medication or "Medication"


@router.post("/portal/cases/{case_id}/prescriptions")
def order_prescription(case_id: UUID, payload: PrescriptionIn, staff: StaffAccount = Depends(facility_staff),
                       db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Cannot order medication for a discharged patient")
    drug = payload.resolved_name
    allergies = [a.strip().lower() for a in (c.allergies or "").split(",") if a.strip()]
    if any(a and a in drug.lower() for a in allergies):
        raise HTTPException(status_code=409, detail=f"{c.patient_name} is allergic to {drug}")
    rx = {"drug_name": drug, "medication": drug, "dosage": payload.dosage, "frequency": payload.frequency,
          "duration": payload.duration, "instructions": payload.instructions or "", "prescribed_by": staff.full_name}
    desc = f"Rx: {drug} {payload.dosage} ({payload.frequency} for {payload.duration})"
    _event(c, staff.full_name, "prescription", desc, rx)
    _audit(db, staff, "case.prescription", str(c.id), desc)
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    return _case_full(db, c)


class InpatientVitalsIn(BaseModel):
    heart_rate: Optional[int] = Field(default=None, ge=20, le=250)
    blood_oxygen: Optional[float] = Field(default=None, ge=50, le=100)
    bp_systolic: Optional[int] = Field(default=None, ge=40, le=300)
    bp_diastolic: Optional[int] = Field(default=None, ge=20, le=200)
    blood_pressure: Optional[str] = Field(default=None, max_length=30)  # "120/80", older clients
    temperature: Optional[float] = Field(default=None, ge=25.0, le=45.0)
    respiratory_rate: Optional[int] = Field(default=None, ge=3, le=80)
    pain: Optional[int] = Field(default=None, ge=0, le=10)
    alert: Optional[bool] = None
    notes: Optional[str] = Field(default=None, max_length=200)


@router.post("/portal/cases/{case_id}/vitals")
def record_vitals(case_id: UUID, payload: InpatientVitalsIn, staff: StaffAccount = Depends(facility_staff),
                  db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Cannot record vitals for a discharged patient")
    sys_, dia = payload.bp_systolic, payload.bp_diastolic
    if (sys_ is None or dia is None) and payload.blood_pressure and "/" in payload.blood_pressure:
        try:
            sys_, dia = (int(x.strip()) for x in payload.blood_pressure.split("/", 1))
        except ValueError:
            raise HTTPException(status_code=400, detail="Blood pressure must look like 120/80")
    v = PortalCaseVitals(
        case_id=c.id, hospital_id=c.hospital_id, heart_rate=payload.heart_rate, bp_systolic=sys_,
        bp_diastolic=dia, spo2=payload.blood_oxygen, temperature=payload.temperature,
        respiratory_rate=payload.respiratory_rate, pain=payload.pain, alert=payload.alert,
        recorded_by=staff.full_name,
    )
    if all(x is None for x in (v.heart_rate, v.bp_systolic, v.spo2, v.temperature, v.respiratory_rate, v.pain, v.alert)):
        raise HTTPException(status_code=400, detail="Enter at least one reading")
    score, red = portal_rules.early_warning({
        "heart_rate": v.heart_rate, "bp_systolic": v.bp_systolic, "spo2": v.spo2,
        "temperature": v.temperature, "respiratory_rate": v.respiratory_rate, "alert": v.alert})
    v.early_warning = score
    db.add(v)
    parts = []
    if v.heart_rate is not None: parts.append(f"HR {v.heart_rate}")
    if v.bp_systolic is not None and v.bp_diastolic is not None: parts.append(f"BP {v.bp_systolic}/{v.bp_diastolic}")
    if v.spo2 is not None: parts.append(f"SpO₂ {v.spo2:g}%")
    if v.temperature is not None: parts.append(f"Temp {v.temperature:g}°C")
    if v.respiratory_rate is not None: parts.append(f"RR {v.respiratory_rate}")
    if v.pain is not None: parts.append(f"Pain {v.pain}/10")
    if v.alert is False: parts.append("not fully alert")
    text = "Vitals: " + ", ".join(parts) + (f" ({payload.notes})" if payload.notes else "")
    _event(c, staff.full_name, "vitals", text, {k: val for k, val in _vitals_out(v).items() if val is not None and k not in ("at", "recorded_by")})
    warn = score is not None and (score >= portal_rules.EARLY_WARNING_ALERT or red)
    if warn:
        _event(c, "VitaNet", "warning", f"Early warning score {score} — review by a clinician now")
    _audit(db, staff, "case.vitals", str(c.id), text)
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    if warn:
        hub.publish(staff.hospital_id, "alert", c.id)
    return _case_full(db, c)


@router.post("/portal/cases/{case_id}/discharge")
def discharge_case(case_id: UUID, payload: DischargeIn, staff: StaffAccount = Depends(facility_staff),
                   db: Session = Depends(get_db)):
    c = _get_case(db, staff, case_id)
    if c.status == "discharged":
        raise HTTPException(status_code=409, detail="Case is already discharged")
    if payload.outcome not in OUTCOMES:
        raise HTTPException(status_code=400, detail="Outcome must be home, admitted, transferred or left")
    had_ward = c.ward_id is not None
    _set_ward(db, staff, c, None)
    c.status, c.discharge_summary, c.outcome = "discharged", payload.summary.strip(), payload.outcome
    _event(c, staff.full_name, "discharge", {
        "home": "Discharged home", "admitted": "Admitted", "transferred": "Transferred",
        "left": "Left before treatment finished"}[payload.outcome])
    if c.referral_id:
        r = db.query(Referral).filter(Referral.id == c.referral_id).first()
        if r and r.status in ("accepted", "arrived"):
            r.status = "closed"
    _audit(db, staff, "case.discharge", str(c.id), payload.outcome)
    db.commit()
    hub.publish(staff.hospital_id, "case", c.id)
    if c.referral_id:
        hub.publish(staff.hospital_id, "referral", c.referral_id)
    if had_ward:
        hub.publish(staff.hospital_id, "capacity")
    return _case_full(db, c)


class HandoverIn(BaseModel):
    to_uid: str
    note: Optional[str] = Field(default=None, max_length=1000)
    end_shift: bool = True


@router.post("/portal/handover")
def handover(payload: HandoverIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """End of shift: hand all my active patients to a colleague on shift."""
    to = _resolve_assignee(db, staff, payload.to_uid)
    if to.firebase_uid == staff.firebase_uid:
        raise HTTPException(status_code=400, detail="Choose someone else")
    cases = db.query(PortalCase).filter(PortalCase.hospital_id == staff.hospital_id,
                                        PortalCase.assignee_uid == staff.firebase_uid,
                                        PortalCase.status.in_(ACTIVE_CASE)).all()
    for c in cases:
        c.assignee_uid, c.assignee_name = to.firebase_uid, to.full_name
        _event(c, staff.full_name, "handover",
               f"Handed over to {to.full_name}" + (f": {payload.note.strip()}" if payload.note and payload.note.strip() else ""))
    if payload.end_shift:
        staff.on_duty = False
    _audit(db, staff, "handover", to.firebase_uid, f"{len(cases)} patients")
    db.commit()
    for c in cases:
        hub.publish(staff.hospital_id, "case", c.id)
    hub.publish(staff.hospital_id, "team")
    return {"handed_over": len(cases), "to": to.full_name}


# ───────────────────────── staff: alerts ─────────────────────────

def _alerts(db: Session, hid) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for b in (db.query(PortalBroadcast).filter(PortalBroadcast.hospital_id == hid)
              .order_by(PortalBroadcast.created_at.desc()).limit(30)):
        out.append({"id": f"bc-{b.id}", "kind": "broadcast", "severity": b.severity, "title": b.title,
                    "body": b.message, "department": b.department, "author_name": b.author_name,
                    "at": _iso(b.created_at)})

    open_refs = db.query(Referral).filter(Referral.hospital_id == hid, Referral.status.in_(OPEN_REFERRAL)).all()
    for r in open_refs:
        if r.status == "new" and r.triage_level == "urgent":
            s = r.summary or {}
            out.append({"id": f"ref-{r.id}", "kind": "referral", "severity": "critical",
                        "title": f"Urgent patient incoming · {s.get('patient_name', 'Patient')}",
                        "body": s.get("complaint"), "referral_id": str(r.id), "at": _iso(r.created_at)})

    # Watch alerts from patients heading here, raised since they referred themselves.
    since = {}
    for r in open_refs:
        since[r.patient_user_id] = min(since.get(r.patient_user_id, r.created_at), r.created_at)
    if since:
        for a in (db.query(HealthAlert).filter(HealthAlert.user_id.in_(list(since)))
                  .order_by(HealthAlert.created_at.desc()).limit(50)):
            if a.created_at < since[a.user_id]:
                continue
            ref = next((r for r in open_refs if r.patient_user_id == a.user_id), None)
            name = (ref.summary or {}).get("patient_name", "Patient") if ref else "Patient"
            out.append({"id": f"vit-{a.id}", "kind": "vitals",
                        "severity": "critical" if getattr(a.severity, "value", a.severity) == "urgent" else "warning",
                        "title": f"{(a.vital_type or 'Vital sign').replace('_', ' ').capitalize()} alert · {name}",
                        "body": a.message,
                        "referral_id": str(ref.id) if ref else None, "at": _iso(a.created_at)})

    # Early warning from observations recorded here in the last 12 hours (latest per patient).
    active = {c.id: c for c in db.query(PortalCase).filter(PortalCase.hospital_id == hid,
                                                             PortalCase.status.in_(ACTIVE_CASE))}
    for cid, v in _latest_vitals(db, active).items():
        if v.early_warning is None or v.early_warning < portal_rules.EARLY_WARNING_ALERT:
            continue
        if v.at < datetime.utcnow() - timedelta(hours=12):
            continue
        c = active[cid]
        out.append({"id": f"ews-{v.id}", "kind": "early_warning",
                    "severity": "critical" if v.early_warning >= 7 else "warning",
                    "title": f"Early warning score {v.early_warning} · {c.patient_name}",
                    "body": "Review by a clinician now.", "case_id": str(c.id), "at": _iso(v.at)})
    out.sort(key=lambda x: x["at"], reverse=True)
    return out


def _with_acks(db: Session, staff: StaffAccount, alerts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    keys = [a["id"] for a in alerts]
    acks: Dict[str, List[PortalAlertAck]] = {}
    if keys:
        for k in db.query(PortalAlertAck).filter(PortalAlertAck.hospital_id == staff.hospital_id,
                                                 PortalAlertAck.alert_key.in_(keys)):
            acks.setdefault(k.alert_key, []).append(k)
    for a in alerts:
        mine = acks.get(a["id"], [])
        a["ack_count"] = len(mine)
        a["ack_names"] = [k.name for k in mine if k.name]
        a["acked_by_me"] = any(k.uid == staff.firebase_uid for k in mine)
    return alerts


@router.get("/portal/alerts")
def portal_alerts(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    return _with_acks(db, staff, _alerts(db, staff.hospital_id))


@router.post("/portal/alerts/{alert_key}/ack")
def ack_alert(alert_key: str, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    """"I'm on it". Idempotent."""
    alerts = {a["id"]: a for a in _alerts(db, staff.hospital_id)}
    if alert_key not in alerts:
        raise HTTPException(status_code=404, detail="Alert not found")
    exists = db.query(PortalAlertAck).filter(PortalAlertAck.hospital_id == staff.hospital_id,
                                             PortalAlertAck.alert_key == alert_key,
                                             PortalAlertAck.uid == staff.firebase_uid).first()
    if not exists:
        db.add(PortalAlertAck(hospital_id=staff.hospital_id, alert_key=alert_key, uid=staff.firebase_uid,
                              name=staff.full_name))
        db.commit()
        hub.publish(staff.hospital_id, "alert", alert_key)
    return _with_acks(db, staff, [alerts[alert_key]])[0]


class CreateAlertIn(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    message: str = Field(..., min_length=5, max_length=500)
    severity: str = Field(default="warning")
    department: Optional[str] = Field(default=None, max_length=100)


@router.post("/portal/alerts")
def create_portal_alert(payload: CreateAlertIn, staff: StaffAccount = Depends(facility_staff),
                        db: Session = Depends(get_db)):
    """Broadcast an operational notice to everyone at this hospital."""
    if payload.severity not in SEVERITIES:
        raise HTTPException(status_code=400, detail="Severity must be critical, warning or info")
    now = datetime.utcnow()
    b = PortalBroadcast(hospital_id=staff.hospital_id, title=payload.title.strip(), message=payload.message.strip(),
                        severity=payload.severity, department=payload.department, author_name=staff.full_name,
                        created_at=now, at=now)
    db.add(b)
    _audit(db, staff, "alert.broadcast", payload.title, payload.severity)
    db.commit()
    db.refresh(b)
    hub.publish(staff.hospital_id, "alert", f"bc-{b.id}")
    return {"id": f"bc-{b.id}", "kind": "broadcast", "severity": b.severity, "title": b.title, "body": b.message,
            "department": b.department, "author_name": b.author_name, "at": _iso(b.created_at),
            "ack_count": 0, "ack_names": [], "acked_by_me": False}


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


def _staff_out(s: StaffAccount, active: Optional[Dict[str, int]] = None) -> Dict[str, Any]:
    return {"firebase_uid": s.firebase_uid, "full_name": s.full_name, "email": s.email,
            "role": s.role.value, "status": s.status.value, "on_duty": bool(s.on_duty),
            "department": s.department, "license_number": s.license_number,
            "review_note": s.review_note, "active_cases": (active or {}).get(s.firebase_uid, 0),
            "created_at": s.created_at.isoformat() if s.created_at else None}


def _ward_out(db: Session, w: PortalWard) -> Dict[str, Any]:
    patients = [c.patient_name for c in db.query(PortalCase).filter(
        PortalCase.ward_id == w.id, PortalCase.status.in_(ACTIVE_CASE)).order_by(PortalCase.created_at)]
    return {"id": w.id, "name": w.name, "beds_total": w.beds_total, "beds_occupied": w.beds_occupied,
            "critical": w.critical, "patients": patients}


@router.get("/portal/capacity")
def capacity(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    hid = staff.hospital_id
    active = portal_rules.active_case_counts(db, hid)
    return {
        "wards": [_ward_out(db, w) for w in db.query(PortalWard).filter(PortalWard.hospital_id == hid).order_by(PortalWard.id)],
        "equipment": [{"id": e.id, "name": e.name, "available": e.available, "total": e.total, "note": e.note}
                      for e in db.query(PortalEquipment).filter(PortalEquipment.hospital_id == hid).order_by(PortalEquipment.id)],
        "team": [_staff_out(s, active) for s in db.query(StaffAccount).filter(
            StaffAccount.hospital_id == hid, StaffAccount.status == StaffStatus.APPROVED).order_by(StaffAccount.full_name)],
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
    hub.publish(staff.hospital_id, "capacity")
    return _ward_out(db, w)


@router.put("/portal/wards/{ward_id}")
def update_ward(ward_id: int, payload: WardIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    """Admins only. Occupied beds normally follow patients; a manual change
    here is a correction and is logged."""
    w = db.query(PortalWard).filter(PortalWard.id == ward_id, PortalWard.hospital_id == staff.hospital_id).first()
    if not w:
        raise HTTPException(status_code=404, detail="Ward not found")
    _check_beds(payload.beds_total, payload.beds_occupied)
    before = f"{w.name} {w.beds_occupied}/{w.beds_total}"
    for k, v in payload.model_dump().items():
        setattr(w, k, v)
    _audit(db, staff, "ward.update", w.name, f"{before} → {w.beds_occupied}/{w.beds_total}")
    db.commit()
    hub.publish(staff.hospital_id, "capacity")
    return _ward_out(db, w)


@router.delete("/portal/wards/{ward_id}", status_code=204)
def delete_ward(ward_id: int, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    w = db.query(PortalWard).filter(PortalWard.id == ward_id, PortalWard.hospital_id == staff.hospital_id).first()
    if not w:
        raise HTTPException(status_code=404, detail="Ward not found")
    if db.query(PortalCase).filter(PortalCase.ward_id == ward_id, PortalCase.status.in_(ACTIVE_CASE)).count():
        raise HTTPException(status_code=409, detail="Move patients out of this ward first")
    db.delete(w)
    _audit(db, staff, "ward.delete", w.name)
    db.commit()
    hub.publish(staff.hospital_id, "capacity")


@router.post("/portal/equipment")
def add_equipment(payload: EquipmentIn, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    if payload.available > payload.total:
        raise HTTPException(status_code=400, detail="Available can't exceed total")
    e = PortalEquipment(hospital_id=staff.hospital_id, **payload.model_dump())
    db.add(e)
    _audit(db, staff, "equipment.create", payload.name)
    db.commit()
    hub.publish(staff.hospital_id, "capacity")
    return {"id": e.id, **payload.model_dump()}


@router.put("/portal/equipment/{equipment_id}")
def update_equipment(equipment_id: int, payload: EquipmentIn, staff: StaffAccount = Depends(facility_staff),
                     db: Session = Depends(get_db)):
    """Anyone on staff can update how many are free; only admins rename or resize."""
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
    hub.publish(staff.hospital_id, "capacity")
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
    hub.publish(staff.hospital_id, "capacity")


class StaffProfileIn(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    department: Optional[str] = Field(default=None, max_length=120)
    license_number: Optional[str] = Field(default=None, max_length=80)


@router.put("/portal/me/profile")
def update_my_profile(payload: StaffProfileIn, staff: StaffAccount = Depends(require_staff),
                      db: Session = Depends(get_db)):
    """Staff edit their own name, department and licence (not role/status)."""
    staff.full_name = payload.full_name.strip()
    staff.department = payload.department
    staff.license_number = payload.license_number
    if staff.hospital_id is not None:
        _audit(db, staff, "profile.update")
    db.commit()
    hub.publish(staff.hospital_id, "team")
    return _staff_out(staff)


@router.put("/portal/me/duty")
def set_duty(payload: DutyIn, staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    staff.on_duty = payload.on_duty
    _audit(db, staff, "duty.on" if payload.on_duty else "duty.off")
    db.commit()
    hub.publish(staff.hospital_id, "team")
    return _staff_out(staff)


@router.get("/portal/team")
def team(staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    """Everyone linked to this hospital, including pending/rejected/suspended."""
    active = portal_rules.active_case_counts(db, staff.hospital_id)
    rows = db.query(StaffAccount).filter(StaffAccount.hospital_id == staff.hospital_id).order_by(StaffAccount.created_at.desc())
    return [_staff_out(s, active) for s in rows]


@router.get("/portal/audit")
def audit_log(limit: int = 100, staff: StaffAccount = Depends(facility_admin), db: Session = Depends(get_db)):
    rows = (db.query(AuditLog).filter(AuditLog.hospital_id == staff.hospital_id)
            .order_by(AuditLog.at.desc()).limit(max(1, min(limit, 500))))
    return [{"at": _iso(a.at), "actor": a.actor_name, "action": a.action, "target": a.target,
             "detail": a.detail} for a in rows]
