from typing import List, Optional
from pydantic import BaseModel


class TriagePredictRequest(BaseModel):
    symptoms: List[str]
    age: Optional[int] = 40
    gender: Optional[str] = "M"
    heart_rate: Optional[float] = 80.0
    temperature: Optional[float] = 37.0
    blood_oxygen: Optional[float] = 98.0
    systolic_bp: Optional[float] = 120.0
    diastolic_bp: Optional[float] = 80.0


class TriagePredictResponse(BaseModel):
    disease: str
    confidence: str
    severity: str  # "urgent", "doctor", "routine"
    severity_confidence: str
    description: str
    precautions: List[str]
    recommendation: str

