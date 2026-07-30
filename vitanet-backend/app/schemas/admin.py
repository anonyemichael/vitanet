from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

class HospitalStatsOut(BaseModel):
    activePatients: int
    availableWards: int
    systemHealth: str
    staffOnDuty: int

class AdminPatientOut(BaseModel):
    id: str
    name: str
    age: Optional[int] = None
    gender: str = "Unknown"
    status: str = "Stable"
    lastUpdated: datetime

class WardInfoOut(BaseModel):
    name: str
    occupied: int
    total: int
    type: str

class StaffInfoOut(BaseModel):
    name: str
    role: str
    status: str
