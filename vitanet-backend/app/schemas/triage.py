from typing import List, Optional
from pydantic import BaseModel, Field


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
    # the rest of the guided assessment (audit F-04); each can only raise the urgency
    pain: Optional[int] = Field(default=None, ge=0, le=10)
    duration_days: Optional[int] = Field(default=None, ge=0, le=3650)
    risk_factors: List[str] = Field(default_factory=list, max_length=20)
    body_area: Optional[str] = Field(default=None, max_length=40)   # where it is; not a symptom


class TriagePredictResponse(BaseModel):
    disease: str
    confidence: str
    severity: str  # "urgent", "doctor", "routine"
    severity_confidence: str   # the rule that set the severity (no invented percentages)
    method: str = "rules-based symptom checker (not a trained model, not a diagnosis)"
    description: str
    precautions: List[str]
    recommendation: str

