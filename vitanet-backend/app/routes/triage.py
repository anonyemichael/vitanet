from fastapi import Depends
from app.dependencies.security import get_current_user
from fastapi import APIRouter, HTTPException
from typing import List
from app.schemas.triage import TriagePredictRequest, TriagePredictResponse
from app.services.ml_service import ml_service, SYMPTOM_MAP

router = APIRouter(prefix="/triage", tags=["triage"], dependencies=[Depends(get_current_user)])


@router.post("/predict", response_model=TriagePredictResponse)
def predict_triage(payload: TriagePredictRequest):
    """Predict disease and clinical severity using ML models trained on 377 symptoms and vitals.

    Only vitals the client actually measured are passed on. The API never
    invents a reading: a vital that was not measured is simply absent, and the
    model scores severity from symptoms and whatever was measured."""
    try:
        measured = {
            k: v for k, v in {
                "age": payload.age, "gender": payload.gender,
                "heart_rate": payload.heart_rate, "temperature": payload.temperature,
                "blood_oxygen": payload.blood_oxygen,
                "systolic_bp": payload.systolic_bp, "diastolic_bp": payload.diastolic_bp,
                "pain": payload.pain, "duration_days": payload.duration_days,
                "risk_factors": payload.risk_factors or None,
            }.items() if v is not None
        }
        result = ml_service.predict_triage(symptoms=payload.symptoms, **measured)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")


@router.get("/symptoms", response_model=List[str])
def list_available_symptoms():
    """Returns list of recognized symptoms for user input autocompletion."""
    return sorted(list(set(SYMPTOM_MAP.keys())))

