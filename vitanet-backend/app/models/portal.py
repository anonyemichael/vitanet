# app/models/portal.py
"""Hospital portal data. Every row belongs to one hospital (facility), and all
portal queries are scoped to the signed-in staff member's hospital."""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import JSON, Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy import Uuid as UUID

from app.database.base import Base


class FacilityRegistration(Base):
    """Marks a row of `hospitals` as a facility that uses the VitaNet portal
    (created by its admin). Only registered facilities receive referrals."""

    __tablename__ = "portal_facilities"

    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), primary_key=True)
    created_by = Column(String(128), nullable=False)
    accepting_referrals = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Referral(Base):
    __tablename__ = "portal_referrals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    patient_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    # new → accepted → arrived → closed, or declined / cancelled
    status = Column(String(16), nullable=False, default="new")
    triage_level = Column(String(16), nullable=False)  # urgent|doctor|pharmacist|self_care|routine
    source = Column(String(16), nullable=False, default="app")  # app|checkin
    summary = Column(JSON, nullable=False, default=dict)  # consented snapshot shown to staff
    consent_at = Column(DateTime, nullable=False)
    patient_lat = Column(Float, nullable=True)
    patient_lng = Column(Float, nullable=True)
    eta_minutes = Column(Integer, nullable=True)
    decline_reason = Column(String(500), nullable=True)
    handled_by = Column(String(128), nullable=True)
    case_id = Column(UUID(as_uuid=True), nullable=True)
    arrived_at = Column(DateTime, nullable=True)
    brief = Column(JSON, nullable=True)  # cached pre-arrival brief
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class PortalCase(Base):
    __tablename__ = "portal_cases"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    referral_id = Column(UUID(as_uuid=True), nullable=True)
    patient_user_id = Column(UUID(as_uuid=True), nullable=True)
    patient_name = Column(String(150), nullable=False)
    age = Column(Integer, nullable=True)
    sex = Column(String(16), nullable=True)
    complaint = Column(String(300), nullable=False)
    level = Column(String(16), nullable=False)  # urgent|doctor|routine
    # expected (accepted, on the way) → waiting (arrived) → treatment → discharged
    status = Column(String(16), nullable=False, default="waiting")
    arrived_at = Column(DateTime, nullable=True)
    outcome = Column(String(20), nullable=True)  # home|admitted|transferred|left
    ward_id = Column(Integer, nullable=True)
    bed = Column(String(40), nullable=True)
    assignee_uid = Column(String(128), nullable=True)
    assignee_name = Column(String(150), nullable=True)
    allergies = Column(String(300), nullable=True)
    timeline = Column(JSON, nullable=False, default=list)  # [{at, by, kind, text}]
    discharge_summary = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class PortalWard(Base):
    __tablename__ = "portal_wards"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    beds_total = Column(Integer, nullable=False, default=0)
    beds_occupied = Column(Integer, nullable=False, default=0)
    critical = Column(Boolean, nullable=False, default=False)


class PortalEquipment(Base):
    __tablename__ = "portal_equipment"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    available = Column(Integer, nullable=False, default=0)
    total = Column(Integer, nullable=False, default=0)
    note = Column(String(200), nullable=True)


class AuditLog(Base):
    __tablename__ = "portal_audit"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hospital_id = Column(UUID(as_uuid=True), nullable=True, index=True)
    actor_uid = Column(String(128), nullable=False)
    actor_name = Column(String(150), nullable=True)
    action = Column(String(60), nullable=False)
    target = Column(String(80), nullable=True)
    detail = Column(Text, nullable=True)
    at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class PortalBroadcast(Base):
    __tablename__ = "portal_broadcasts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    title = Column(String(150), nullable=False)
    message = Column(Text, nullable=False)
    severity = Column(String(20), nullable=False, default="warning")  # critical|warning|info
    department = Column(String(100), nullable=True)
    author_name = Column(String(150), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class PortalCaseVitals(Base):
    """One set of observations recorded by staff for a case."""

    __tablename__ = "portal_case_vitals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    case_id = Column(UUID(as_uuid=True), ForeignKey("portal_cases.id"), nullable=False, index=True)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    heart_rate = Column(Integer, nullable=True)
    bp_systolic = Column(Integer, nullable=True)
    bp_diastolic = Column(Integer, nullable=True)
    spo2 = Column(Float, nullable=True)
    temperature = Column(Float, nullable=True)
    respiratory_rate = Column(Integer, nullable=True)
    pain = Column(Integer, nullable=True)
    alert = Column(Boolean, nullable=True)  # not fully alert (confused, drowsy…)
    early_warning = Column(Integer, nullable=True)  # NEWS2-style score
    recorded_by = Column(String(150), nullable=True)
    at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class PortalAlertAck(Base):
    """A staff member saying "I'm on it" for an alert."""

    __tablename__ = "portal_alert_acks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hospital_id = Column(UUID(as_uuid=True), ForeignKey("hospitals.id"), nullable=False, index=True)
    alert_key = Column(String(80), nullable=False, index=True)
    uid = Column(String(128), nullable=False)
    name = Column(String(150), nullable=True)
    at = Column(DateTime, default=datetime.utcnow, nullable=False)
