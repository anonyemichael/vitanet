from fastapi import Depends
from app.dependencies.security import get_current_user
from fastapi import APIRouter, HTTPException
from typing import List
from app.schemas.triage import TriagePredictRequest, TriagePredictResponse
from app.services.ml_service import ml_service, SYMPTOM_MAP

router = APIRouter(prefix="/triage", tags=["triage"], dependencies=[Depends(get_current_user)])


@router.post("/predict", response_model=TriagePredictResponse)
def predict_triage(payload: TriagePredictRequest):
    """Predict disease and clinical severity using ML models trained on 377 symptoms and vitals."""
    try:
        result = ml_service.predict_triage(
            symptoms=payload.symptoms,
            age=payload.age or 40,
            gender=payload.gender or "M",
            heart_rate=payload.heart_rate or 80.0,
            temperature=payload.temperature or 37.0,
            blood_oxygen=payload.blood_oxygen or 98.0,
            systolic_bp=payload.systolic_bp or 120.0,
            diastolic_bp=payload.diastolic_bp or 80.0,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")


@router.get("/symptoms", response_model=List[str])
def list_available_symptoms():
    """Returns list of recognized symptoms for user input autocompletion."""
    return sorted(list(set(SYMPTOM_MAP.keys())))

