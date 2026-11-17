from typing import List, Optional
from pydantic import BaseModel


class TriagePredictRequest(BaseModel):
    """Only what the person or their device actually gave. Nothing is filled in: a reading that was not
    measured stays None and is left out of the scoring (audit F-01)."""
    symptoms: List[str]
    age: Optional[int] = None
    gender: Optional[str] = None
    heart_rate: Optional[float] = None
    temperature: Optional[float] = None
    blood_oxygen: Optional[float] = None
    systolic_bp: Optional[float] = None
    diastolic_bp: Optional[float] = None


class TriagePredictResponse(BaseModel):
    disease: str
    confidence: str
    severity: str  # "urgent", "doctor", "routine"
    severity_confidence: str
    description: str
    precautions: List[str]
    recommendation: str

