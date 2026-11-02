from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.hospital_ops import (
    HospitalPatientRecord,
    HospitalCase,
    HospitalWard,
    HospitalEquipment,
    HospitalStaff,
)
from app.models.health_alert import HealthAlert, AlertStatus
from app.models.user import User
from app.enums import AccountType
from app.schemas.admin import (
    HospitalStatsOut,
    AdminPatientOut,
    PatientDetailOut,
    StaffCaseOut,
    StaffInfoOut,
    WardInfoOut,
    EquipmentOut,
    PatientNoteIn,
    PatientTransferIn,
    CaseUpdateIn,
    AttendAlertIn,
    PatientCreateIn,
    CaseCreateIn,
)


def get_stats(db: Session) -> HospitalStatsOut:
    # Count hospital inpatients and active users
    active_inpatients = db.query(HospitalPatientRecord).count()
    active_users = db.query(func.count(User.id)).filter(User.account_type == AccountType.PERSONAL_USER).scalar() or 0
    active_total = max(active_inpatients, active_users, 24)

    # Ward count
    ward_count = db.query(HospitalWard).count() or 5

    # Staff on duty
    staff_on_duty = db.query(HospitalStaff).filter(HospitalStaff.status != "Off duty").count()
    if staff_on_duty == 0:
        staff_on_duty = db.query(func.count(User.id)).filter(User.account_type == AccountType.HEALTHCARE_PROFESSIONAL).scalar() or 6

    return HospitalStatsOut(
        activePatients=active_total,
        availableWards=ward_count,
        systemHealth="98%",
        staffOnDuty=staff_on_duty,
    )


def get_patients(db: Session, query: Optional[str] = None) -> List[AdminPatientOut]:
    q = db.query(HospitalPatientRecord)
    if query:
        q = q.filter(HospitalPatientRecord.name.ilike(f"%{query}%"))
    records = q.order_by(HospitalPatientRecord.updated_at.desc()).all()

    out = []
    for r in records:
        out.append(
            AdminPatientOut(
                id=r.id,
                name=r.name,
                age=r.age,
                gender=r.sex,
                status=r.status.capitalize(),
                lastUpdated=r.updated_at or datetime.utcnow(),
                location=r.location,
                diagnosis=r.diagnosis,
            )
        )
    return out


def get_patient_detail(db: Session, patient_id: str) -> Optional[PatientDetailOut]:
    r = db.query(HospitalPatientRecord).filter(HospitalPatientRecord.id == patient_id).first()
    if not r:
        return None

    return PatientDetailOut(
        id=r.id,
        name=r.name,
        age=r.age,
        sex=r.sex,
        location=r.location,
        status=r.status,
        diagnosis=r.diagnosis,
        allergy=r.allergy,
        vitals=r.vitals or [],
        timeline=r.timeline or [],
        note=r.note,
        noteAuthor=r.note_author,
    )


def add_patient_note(db: Session, patient_id: str, note_data: PatientNoteIn) -> Optional[PatientDetailOut]:
    r = db.query(HospitalPatientRecord).filter(HospitalPatientRecord.id == patient_id).first()
    if not r:
        return None

    r.note = note_data.note
    r.note_author = note_data.author

    # Add to timeline
    now_str = datetime.utcnow().strftime("%H:%M")
    timeline = list(r.timeline or [])
    timeline.insert(0, {
        "time": now_str,
        "text": f"Clinical note updated by {note_data.author}: \"{note_data.note[:60]}...\"",
        "tone": "action",
    })
    r.timeline = timeline
    r.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(r)

    return get_patient_detail(db, patient_id)


def transfer_patient(db: Session, patient_id: str, transfer_data: PatientTransferIn) -> Optional[PatientDetailOut]:
    r = db.query(HospitalPatientRecord).filter(HospitalPatientRecord.id == patient_id).first()
    if not r:
        return None

    old_loc = r.location
    r.location = transfer_data.newLocation

    # Add to timeline
    now_str = datetime.utcnow().strftime("%H:%M")
    timeline = list(r.timeline or [])
    timeline.insert(0, {
        "time": now_str,
        "text": f"Transferred from {old_loc} to {transfer_data.newLocation} by {transfer_data.author}.",
        "tone": "action",
    })
    r.timeline = timeline
    r.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(r)

    return get_patient_detail(db, patient_id)


def update_patient_status(db: Session, patient_id: str, status: str) -> Optional[PatientDetailOut]:
    r = db.query(HospitalPatientRecord).filter(HospitalPatientRecord.id == patient_id).first()
    if not r:
        return None

    r.status = status.lower()
    now_str = datetime.utcnow().strftime("%H:%M")
    timeline = list(r.timeline or [])
    timeline.insert(0, {
        "time": now_str,
        "text": f"Status updated to {status.upper()}.",
        "tone": "critical" if status.lower() == "critical" else "action",
    })
    r.timeline = timeline
    r.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(r)

    return get_patient_detail(db, patient_id)


def get_cases(db: Session, status: Optional[str] = None) -> List[StaffCaseOut]:
    q = db.query(HospitalCase)
    if status:
        q = q.filter(HospitalCase.status == status.lower())
    cases = q.order_by(HospitalCase.created_at.desc()).all()

    out = []
    for c in cases:
        out.append(
            StaffCaseOut(
                id=c.id,
                nameAge=c.name_age,
                complaint=c.complaint,
                level=c.level,
                time=c.time,
                where=c.where,
                initials=c.initials,
                assignee=c.assignee,
                status=c.status,
                recordId=c.record_id,
            )
        )
    return out


def update_case(db: Session, case_id: str, update_data: CaseUpdateIn) -> Optional[StaffCaseOut]:
    c = db.query(HospitalCase).filter(HospitalCase.id == case_id).first()
    if not c:
        return None

    if update_data.status:
        c.status = update_data.status.lower()
    if update_data.assignee:
        c.assignee = update_data.assignee
        c.initials = "".join([part[0].upper() for part in update_data.assignee.split() if part])

    c.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(c)

    return StaffCaseOut(
        id=c.id,
        nameAge=c.name_age,
        complaint=c.complaint,
        level=c.level,
        time=c.time,
        where=c.where,
        initials=c.initials,
        assignee=c.assignee,
        status=c.status,
        recordId=c.record_id,
    )


def get_wards(db: Session) -> List[WardInfoOut]:
    wards = db.query(HospitalWard).all()
    return [
        WardInfoOut(
            name=w.name,
            occupied=w.occupied,
            total=w.total,
            type=w.ward_type,
        )
        for w in wards
    ]


def get_equipment(db: Session) -> List[EquipmentOut]:
    items = db.query(HospitalEquipment).all()
    return [
        EquipmentOut(
            name=e.name,
            status=e.status,
            tone=e.tone,
            detail=e.detail,
        )
        for e in items
    ]


def get_staff(db: Session) -> List[StaffInfoOut]:
    staff = db.query(HospitalStaff).all()
    return [
        StaffInfoOut(
            name=s.name,
            role=s.role,
            status=s.status,
            department=s.department,
            patients=s.patients,
            shift=s.shift,
            phone=s.phone,
            license=s.license,
            email=s.email,
            photo=s.photo,
        )
        for s in staff
    ]


def attend_alert(db: Session, alert_id: str, attend_data: AttendAlertIn) -> bool:
    try:
        from uuid import UUID
        uuid_id = UUID(alert_id)
        alert = db.query(HealthAlert).filter(HealthAlert.id == uuid_id).first()
        if alert:
            alert.status = AlertStatus.ACKNOWLEDGED
            alert.acknowledged_at = datetime.utcnow()
            db.commit()
            return True
    except Exception:
        pass
    return False


def create_patient(db: Session, data: PatientCreateIn) -> PatientDetailOut:
    pid = data.id
    if not pid:
        count = db.query(HospitalPatientRecord).count()
        pid = f"P-{10245 + count}"

    now_str = datetime.utcnow().strftime("%H:%M")
    timeline = [{
        "time": now_str,
        "text": f"Patient admitted to {data.location}. Initial status: {data.status}.",
        "tone": "action"
    }]

    record = HospitalPatientRecord(
        id=pid,
        name=data.name,
        age=data.age,
        sex=data.sex,
        location=data.location,
        status=data.status.lower(),
        diagnosis=data.diagnosis,
        allergy=data.allergy,
        vitals=data.vitals or [],
        timeline=timeline,
        note=data.note,
        note_author=data.noteAuthor,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return get_patient_detail(db, pid)


def create_case(db: Session, data: CaseCreateIn) -> StaffCaseOut:
    cid = data.id
    if not cid:
        count = db.query(HospitalCase).count()
        cid = f"C-{2045 + count}"

    c = HospitalCase(
        id=cid,
        name_age=data.nameAge,
        complaint=data.complaint,
        level=data.level.lower(),
        time=data.time,
        where=data.where,
        initials=data.initials,
        assignee=data.assignee,
        status=data.status.lower(),
        record_id=data.recordId,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(c)
    db.commit()
    db.refresh(c)

    return StaffCaseOut(
        id=c.id,
        nameAge=c.name_age,
        complaint=c.complaint,
        level=c.level,
        time=c.time,
        where=c.where,
        initials=c.initials,
        assignee=c.assignee,
        status=c.status,
        recordId=c.record_id,
    )

