from typing import Annotated
# app/routers/health_alert.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.dependencies.security import CurrentUser, get_current_user, owned_user_id, current_user_id
from app.models.health_alert import HealthAlert
from app.schemas.health_alert import HealthAlertOut
from app.services import health_alert_service

router = APIRouter(prefix="/alerts", tags=["health-alerts"])


@router.get("/{user_id}", response_model=list[HealthAlertOut])
def list_alerts(user_id: Annotated[UUID, Depends(owned_user_id)], db: Session = Depends(get_db)):
    return db.query(HealthAlert).filter(HealthAlert.user_id == user_id).order_by(HealthAlert.created_at.desc()).all()


@router.post("/{alert_id}/acknowledge", response_model=HealthAlertOut)
def acknowledge(alert_id: UUID, me: Annotated[UUID, Depends(current_user_id)], db: Session = Depends(get_db)):
    owned = db.query(HealthAlert).filter(HealthAlert.id == alert_id, HealthAlert.user_id == me).first()
    if not owned:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert = health_alert_service.acknowledge_alert(db, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert