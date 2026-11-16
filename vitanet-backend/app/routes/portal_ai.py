# app/routes/portal_ai.py
"""Hospital-staff AI and tool endpoints (docs/AI_MODEL_INTEGRATION_PLAN.md section 3, hospital toolbox).

  POST /portal/ai/{task}            prep_brief | triage_check | discharge_draft | handover_note | structure_note
                                    -> {"output", "source": "ai"|"rules", "label"?, "reason"?}
  POST /portal/tools/news2          vitals -> NEWS2-style score
  GET  /portal/tools/ward-capacity  wards with free beds
  GET  /portal/tools/workload       least-burdened on-duty clinician for a level
  POST /portal/tools/allergy-check  drug + allergies -> allowed or not (drug families)

Every AI call is audit-logged; model output is only a suggestion that staff can edit.
"""
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.models.staff_account import StaffAccount
from app.routes.portal import _audit, facility_staff
from app.services import portal_ai, portal_tools

router = APIRouter(tags=["portal-ai"])


@router.post("/portal/ai/{task}")
def portal_ai_task(task: str, payload: Dict[str, Any], staff: StaffAccount = Depends(facility_staff),
                   db: Session = Depends(get_db)):
    if task not in portal_ai.TASKS:
        raise HTTPException(status_code=404, detail=f"Unknown task {task!r}")
    inp = dict(payload, task=task)
    output, info = portal_ai.run_task(inp)
    _audit(db, staff, f"ai.{task}", None, f"source={info['source']}" + (f" ({info.get('reason')})" if info.get("reason") else ""))
    db.commit()
    return {"output": output, **info}


class VitalsIn(BaseModel):
    heart_rate: float | None = None
    bp_systolic: float | None = None
    bp_diastolic: float | None = None
    spo2: float | None = None
    temperature: float | None = None
    respiratory_rate: float | None = None
    alert: bool | None = None


@router.post("/portal/tools/news2")
def news2(payload: VitalsIn, staff: StaffAccount = Depends(facility_staff)):
    return portal_tools.calculate_news2_score(payload.model_dump())


@router.get("/portal/tools/ward-capacity")
def ward_capacity(staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    return portal_tools.check_ward_capacity(db, staff.hospital_id)


@router.get("/portal/tools/workload")
def workload(level: str = Query("doctor", pattern="^(urgent|doctor|routine)$"),
             staff: StaffAccount = Depends(facility_staff), db: Session = Depends(get_db)):
    return portal_tools.balance_clinician_workload(db, staff.hospital_id, level)


class AllergyCheckIn(BaseModel):
    drug: str = Field(max_length=120)
    allergies: List[str] = []


@router.post("/portal/tools/allergy-check")
def allergy_check(payload: AllergyCheckIn, staff: StaffAccount = Depends(facility_staff)):
    return portal_tools.allergy_prescription_guard(payload.drug, payload.allergies)
