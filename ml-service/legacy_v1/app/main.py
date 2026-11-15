from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional, Union
import numpy as np
import os
import sys
from pathlib import Path

# Ensure project root and app directory are in sys.path
project_root = Path(__file__).parent.parent.absolute()
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

app_dir = Path(__file__).parent.absolute()
if str(app_dir) not in sys.path:
    sys.path.insert(0, str(app_dir))

from predict import DiseasePredictor, SYMPTOM_MAPPING

app = FastAPI(
    title="Disease & Severity Prediction API",
    description="API for predicting diseases and severity levels using pre-trained machine learning models",
    version="1.0"
)

# Initialize predictor globally
predictor = None


@app.on_event("startup")
def load_predictor():
    global predictor
    try:
        predictor = DiseasePredictor()
    except Exception as e:
        print(f"Warning: Could not initialize DiseasePredictor on startup: {e}")


def get_predictor():
    global predictor
    if predictor is None:
        predictor = DiseasePredictor()
    return predictor


class PatientData(BaseModel):
    fever: Optional[float] = Field(0.0, description="1.0 if fever present, 0.0 otherwise")
    cough: Optional[float] = Field(0.0, description="1.0 if cough present, 0.0 otherwise")
    headache: Optional[float] = Field(0.0, description="1.0 if headache present, 0.0 otherwise")
    temperature: Optional[float] = Field(37.0, description="Body temperature in Celsius")
    heart_rate: Optional[float] = Field(75.0, description="Heart rate in bpm")
    age: Optional[int] = Field(45, description="Patient age in years")
    gender: Optional[int] = Field(0, description="Gender: 0 for male, 1 for female")
    o2_saturation: Optional[int] = Field(98, description="Oxygen saturation percentage (0-100)")
    systolic_bp: Optional[int] = Field(120, description="Systolic blood pressure (mmHg)")
    diastolic_bp: Optional[int] = Field(80, description="Diastolic blood pressure (mmHg)")
    symptoms: Optional[List[Union[str, int]]] = Field(
        None, description="Optional list of symptom names or feature indices"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "fever": 1.0,
                "cough": 1.0,
                "headache": 0.0,
                "temperature": 38.5,
                "heart_rate": 88.0,
                "age": 45,
                "gender": 0,
                "o2_saturation": 97,
                "systolic_bp": 130,
                "diastolic_bp": 85,
                "symptoms": ["fever", "cough", "shortness_of_breath"]
            }
        }


class SymptomVectorRequest(BaseModel):
    symptoms: List[float] = Field(..., description="Array of 377 binary symptom features (0.0 or 1.0)")


class SeverityRequest(BaseModel):
    age: int = Field(45, description="Patient age")
    gender: int = Field(0, description="0 for male, 1 for female")
    symptoms_list: List[int] = Field([0, 0, 0], description="List of 3 encoded symptom values")
    heart_rate: int = Field(75, description="Heart rate in bpm")
    body_temp: float = Field(37.0, description="Body temperature in Celsius")
    o2_saturation: int = Field(98, description="O2 saturation percentage (0-100)")
    diagnosis: int = Field(0, description="Encoded diagnosis value")
    systolic_bp: int = Field(120, description="Systolic blood pressure")
    diastolic_bp: int = Field(80, description="Diastolic blood pressure")


def build_symptom_array(data: PatientData) -> np.ndarray:
    """Helper to construct 377-element binary symptom array from PatientData."""
    symptoms_array = np.zeros(377)

    # Check explicit fields
    if data.fever and data.fever > 0:
        symptoms_array[SYMPTOM_MAPPING.get('fever', 100)] = 1.0
    if data.cough and data.cough > 0:
        symptoms_array[SYMPTOM_MAPPING.get('cough', 15)] = 1.0
    if data.headache and data.headache > 0:
        symptoms_array[SYMPTOM_MAPPING.get('headache', 250)] = 1.0

    # Check additional symptoms list if provided
    if data.symptoms:
        for s in data.symptoms:
            if isinstance(s, int) and 0 <= s < 377:
                symptoms_array[s] = 1.0
            elif isinstance(s, str):
                s_clean = s.lower().strip()
                if s_clean in SYMPTOM_MAPPING:
                    symptoms_array[SYMPTOM_MAPPING[s_clean]] = 1.0

    return symptoms_array


@app.get("/")
def home():
    """Health check and API information endpoint."""
    return {
        "message": "Disease & Severity Prediction API is running",
        "status": "online",
        "endpoints": {
            "POST /predict": "Predict both disease and severity from patient data",
            "POST /predict/disease": "Predict disease from 377 symptom array",
            "POST /predict/severity": "Predict severity level from vital signs"
        }
    }


@app.post("/predict")
def predict(data: PatientData):
    """
    Predict disease and severity level for a patient.
    Accepts patient symptoms, temperature, heart rate, and vital signs.
    """
    try:
        pred = get_predictor()

        # Build 377 symptom array
        symptoms_array = build_symptom_array(data)

        # Predict disease
        disease_res = pred.predict_disease(symptoms_array)

        # Collect symptom indices present for severity prediction
        active_indices = np.where(symptoms_array == 1.0)[0]
        symptom_indices = list(active_indices[:3])
        while len(symptom_indices) < 3:
            symptom_indices.append(0)

        # Predict severity
        severity_res = pred.predict_severity(
            age=data.age or 45,
            gender=data.gender or 0,
            symptoms_list=symptom_indices,
            heart_rate=int(data.heart_rate or 75),
            body_temp=float(data.temperature or 37.0),
            o2_saturation=data.o2_saturation or 98,
            diagnosis=0,
            systolic_bp=data.systolic_bp or 120,
            diastolic_bp=data.diastolic_bp or 80
        )

        return {
            "disease": disease_res["disease"],
            "disease_confidence": disease_res["confidence_percent"],
            "disease_probability": disease_res["disease_probability"],
            "severity": severity_res["severity"],
            "severity_confidence": severity_res["confidence_percent"],
            "severity_probability": severity_res["severity_probability"]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict/disease")
def predict_disease(data: SymptomVectorRequest):
    """Predict disease from a 377-element binary symptom array."""
    try:
        pred = get_predictor()
        if len(data.symptoms) != 377:
            raise HTTPException(
                status_code=400,
                detail=f"Expected 377 symptom values, got {len(data.symptoms)}"
            )
        result = pred.predict_disease(data.symptoms)
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict/severity")
def predict_severity(data: SeverityRequest):
    """Predict severity level from vital signs and patient parameters."""
    try:
        pred = get_predictor()
        result = pred.predict_severity(
            age=data.age,
            gender=data.gender,
            symptoms_list=data.symptoms_list,
            heart_rate=data.heart_rate,
            body_temp=data.body_temp,
            o2_saturation=data.o2_saturation,
            diagnosis=data.diagnosis,
            systolic_bp=data.systolic_bp,
            diastolic_bp=data.diastolic_bp
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))