from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.database.connection import get_db
from app.schemas.admin import HospitalStatsOut, AdminPatientOut, WardInfoOut, StaffInfoOut
from app.schemas.health_alert import HealthAlertOut
from app.models.health_alert import HealthAlert, AlertStatus
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])

@router.get("/stats", response_model=HospitalStatsOut)
def get_dashboard_stats(db: Session = Depends(get_db)):
    return admin_service.get_stats(db)

@router.get("/patients", response_model=List[AdminPatientOut])
def get_patients(db: Session = Depends(get_db)):
    return admin_service.get_patients(db)

@router.get("/alerts", response_model=List[HealthAlertOut])
def get_alerts(db: Session = Depends(get_db)):
    # Returns all pending or escalated alerts for the admin view
    alerts = db.query(HealthAlert).filter(HealthAlert.status != AlertStatus.ACKNOWLEDGED).order_by(HealthAlert.created_at.desc()).all()
    return alerts

@router.get("/wards", response_model=List[WardInfoOut])
def get_wards(db: Session = Depends(get_db)):
    return admin_service.get_wards(db)

@router.get("/staff", response_model=List[StaffInfoOut])
def get_staff(db: Session = Depends(get_db)):
    return admin_service.get_staff(db)
