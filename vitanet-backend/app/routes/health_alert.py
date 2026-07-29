# app/routers/health_alert.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.models.health_alert import HealthAlert
from app.schemas.health_alert import HealthAlertOut
from app.services import health_alert_service

router = APIRouter(prefix="/alerts", tags=["health-alerts"])


@router.get("/{user_id}", response_model=list[HealthAlertOut])
def list_alerts(user_id: UUID, db: Session = Depends(get_db)):
    return db.query(HealthAlert).filter(HealthAlert.user_id == user_id).order_by(HealthAlert.created_at.desc()).all()


@router.post("/{alert_id}/acknowledge", response_model=HealthAlertOut)
def acknowledge(alert_id: UUID, db: Session = Depends(get_db)):
    alert = health_alert_service.acknowledge_alert(db, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert