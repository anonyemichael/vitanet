from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.connection import get_db
from app.schemas.admin import (
    HospitalStatsOut,
    AdminPatientOut,
    PatientDetailOut,
    StaffCaseOut,
    WardInfoOut,
    EquipmentOut,
    StaffInfoOut,
    PatientNoteIn,
    PatientTransferIn,
    CaseUpdateIn,
    AttendAlertIn,
    PatientCreateIn,
    CaseCreateIn,
)
from app.schemas.health_alert import HealthAlertOut
from app.models.health_alert import HealthAlert, AlertStatus
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=HospitalStatsOut)
def get_dashboard_stats(db: Session = Depends(get_db)):
    return admin_service.get_stats(db)


@router.get("/patients", response_model=List[AdminPatientOut])
def get_patients(
    query: Optional[str] = Query(None, description="Search by patient name"),
    db: Session = Depends(get_db)
):
    return admin_service.get_patients(db, query=query)


@router.post("/patients", response_model=PatientDetailOut)
def create_patient(payload: PatientCreateIn, db: Session = Depends(get_db)):
    return admin_service.create_patient(db, payload)


@router.get("/patients/{patient_id}", response_model=PatientDetailOut)
def get_patient_detail(patient_id: str, db: Session = Depends(get_db)):
    record = admin_service.get_patient_detail(db, patient_id)
    if not record:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return record


@router.post("/patients/{patient_id}/notes", response_model=PatientDetailOut)
def add_patient_note(patient_id: str, payload: PatientNoteIn, db: Session = Depends(get_db)):
    record = admin_service.add_patient_note(db, patient_id, payload)
    if not record:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return record


@router.patch("/patients/{patient_id}/transfer", response_model=PatientDetailOut)
def transfer_patient(patient_id: str, payload: PatientTransferIn, db: Session = Depends(get_db)):
    record = admin_service.transfer_patient(db, patient_id, payload)
    if not record:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return record


@router.patch("/patients/{patient_id}/status", response_model=PatientDetailOut)
def update_patient_status(patient_id: str, status: str = Query(..., description="New status"), db: Session = Depends(get_db)):
    record = admin_service.update_patient_status(db, patient_id, status)
    if not record:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return record


@router.get("/cases", response_model=List[StaffCaseOut])
def get_cases(
    status: Optional[str] = Query(None, description="Filter by status: waiting, treatment, discharged"),
    db: Session = Depends(get_db)
):
    return admin_service.get_cases(db, status=status)


@router.post("/cases", response_model=StaffCaseOut)
def create_case(payload: CaseCreateIn, db: Session = Depends(get_db)):
    return admin_service.create_case(db, payload)


@router.patch("/cases/{case_id}", response_model=StaffCaseOut)
def update_case(case_id: str, payload: CaseUpdateIn, db: Session = Depends(get_db)):
    updated = admin_service.update_case(db, case_id, payload)
    if not updated:
        raise HTTPException(status_code=404, detail="Case not found")
    return updated


@router.get("/alerts", response_model=List[HealthAlertOut])
def get_alerts(db: Session = Depends(get_db)):
    alerts = (
        db.query(HealthAlert)
        .filter(HealthAlert.status != AlertStatus.ACKNOWLEDGED)
        .order_by(HealthAlert.created_at.desc())
        .all()
    )
    return alerts


@router.post("/alerts/{alert_id}/attend")
def attend_alert(alert_id: str, payload: AttendAlertIn, db: Session = Depends(get_db)):
    success = admin_service.attend_alert(db, alert_id, payload)
    return {"acknowledged": success, "alert_id": alert_id}


@router.get("/wards", response_model=List[WardInfoOut])
def get_wards(db: Session = Depends(get_db)):
    return admin_service.get_wards(db)


@router.get("/equipment", response_model=List[EquipmentOut])
def get_equipment(db: Session = Depends(get_db)):
    return admin_service.get_equipment(db)


@router.get("/staff", response_model=List[StaffInfoOut])
def get_staff(db: Session = Depends(get_db)):
    return admin_service.get_staff(db)
