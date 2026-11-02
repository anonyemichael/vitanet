from typing import List, Optional, Any
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
    location: Optional[str] = None
    diagnosis: Optional[str] = None


class PatientDetailOut(BaseModel):
    id: str
    name: str
    age: int
    sex: str
    location: str
    status: str
    diagnosis: Optional[str] = None
    allergy: Optional[str] = None
    vitals: List[Any] = []
    timeline: List[Any] = []
    note: Optional[str] = None
    noteAuthor: Optional[str] = None


class StaffCaseOut(BaseModel):
    id: str
    nameAge: str
    complaint: str
    level: str
    time: str
    where: str
    initials: str
    assignee: str
    status: str
    recordId: Optional[str] = None


class WardInfoOut(BaseModel):
    name: str
    occupied: int
    total: int
    type: str


class EquipmentOut(BaseModel):
    name: str
    status: str
    tone: str
    detail: Optional[str] = None


class StaffInfoOut(BaseModel):
    name: str
    role: str
    status: str
    department: Optional[str] = None
    patients: Optional[str] = None
    shift: Optional[str] = None
    phone: Optional[str] = None
    license: Optional[str] = None
    email: Optional[str] = None
    photo: Optional[str] = None


class PatientNoteIn(BaseModel):
    note: str
    author: str = "Dr. Kwame Mensah"


class PatientTransferIn(BaseModel):
    newLocation: str
    author: Optional[str] = "Dr. Kwame Mensah"


class CaseUpdateIn(BaseModel):
    status: Optional[str] = None
    assignee: Optional[str] = None


class AttendAlertIn(BaseModel):
    note: Optional[str] = None
    staffName: Optional[str] = "Dr. Kwame Mensah"


class PatientCreateIn(BaseModel):
    id: Optional[str] = None
    name: str
    age: int
    sex: str = "F"
    location: str
    status: str = "observation"
    diagnosis: Optional[str] = None
    allergy: Optional[str] = None
    vitals: Optional[List[Any]] = []
    note: Optional[str] = None
    noteAuthor: Optional[str] = "Dr. Kwame Mensah"


class CaseCreateIn(BaseModel):
    id: Optional[str] = None
    nameAge: str
    complaint: str
    level: str = "routine"
    time: str = "Just now"
    where: str
    initials: str = "—"
    assignee: str = "Unassigned"
    status: str = "waiting"
    recordId: Optional[str] = None
