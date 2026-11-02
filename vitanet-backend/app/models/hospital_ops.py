# app/models/hospital_ops.py
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Text, JSON
from app.database.base import Base


class HospitalPatientRecord(Base):
    __tablename__ = "hospital_patient_records"

    id = Column(String(32), primary_key=True)  # e.g. P-10233
    name = Column(String(150), nullable=False)
    age = Column(Integer, nullable=False)
    sex = Column(String(8), nullable=False)  # 'F' / 'M'
    location = Column(String(100), nullable=False)  # 'Emergency · Bed 7'
    status = Column(String(32), nullable=False)  # 'critical', 'observation', 'stable', 'recovering'
    diagnosis = Column(String(255), nullable=True)
    allergy = Column(String(255), nullable=True)
    vitals = Column(JSON, nullable=False, default=list)  # [{"label": "HR", "value": "118", "alert": true}, ...]
    timeline = Column(JSON, nullable=False, default=list)  # [{"time": "10:40", "text": "...", "tone": "critical"}, ...]
    note = Column(Text, nullable=True)
    note_author = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class HospitalCase(Base):
    __tablename__ = "hospital_cases"

    id = Column(String(32), primary_key=True)  # e.g. C-2041
    name_age = Column(String(150), nullable=False)  # e.g. 'Yaw Boateng, 62 M'
    complaint = Column(String(255), nullable=False)  # e.g. 'Chest pain'
    level = Column(String(32), nullable=False)  # 'urgent', 'doctor', 'routine'
    time = Column(String(64), nullable=False)  # '31 min' or 'ETA 9 min'
    where = Column(String(100), nullable=False)  # 'Resus bay 2'
    initials = Column(String(8), nullable=False)  # 'KM'
    assignee = Column(String(100), nullable=False)  # 'Dr. Mensah'
    status = Column(String(32), nullable=False)  # 'waiting', 'treatment', 'discharged'
    record_id = Column(String(32), nullable=True)  # references HospitalPatientRecord.id
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class HospitalWard(Base):
    __tablename__ = "hospital_wards"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False, unique=True)  # 'Emergency', 'ICU', etc.
    occupied = Column(Integer, nullable=False, default=0)
    total = Column(Integer, nullable=False, default=1)
    ward_type = Column(String(32), nullable=False, default="Standard")  # 'Critical', 'Standard'


class HospitalEquipment(Base):
    __tablename__ = "hospital_equipment"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False, unique=True)  # 'Ventilators', 'Oxygen supply', etc.
    status = Column(String(100), nullable=False)  # '6 of 9 free', '72% OK'
    tone = Column(String(32), nullable=False, default="green")  # 'green', 'amber', 'danger'
    detail = Column(String(255), nullable=True)


class HospitalStaff(Base):
    __tablename__ = "hospital_staff"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(150), nullable=False)
    role = Column(String(100), nullable=False)
    status = Column(String(64), nullable=False)  # 'With patient', 'Available', 'In theatre'
    department = Column(String(100), nullable=True)
    patients = Column(String(32), nullable=True)
    shift = Column(String(32), nullable=True)
    phone = Column(String(64), nullable=True)
    license = Column(String(128), nullable=True)
    email = Column(String(150), nullable=True)
    photo = Column(String(255), nullable=True)

