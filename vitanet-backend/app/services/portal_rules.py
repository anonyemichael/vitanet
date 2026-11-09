# app/services/portal_rules.py
"""Deterministic helpers for the portal (no AI): an early-warning score from
observations and a suggested ward and clinician for an incoming patient."""
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.portal import PortalCase, PortalWard
from app.models.staff_account import StaffAccount, StaffRole, StaffStatus

EARLY_WARNING_ALERT = 5  # score at which the team is alerted


def _band(value: Optional[float], bands: List[Tuple[float, int]], top: int) -> Optional[int]:
    """`bands` are (upper_bound_inclusive, points) in ascending order."""
    if value is None:
        return None
    for upper, points in bands:
        if value <= upper:
            return points
    return top


def early_warning(v: Dict[str, Any]) -> Tuple[Optional[int], bool]:
    """NEWS2-style score (room air scale). Returns (score, any_single_red).
    The score is None when fewer than two observations were taken."""
    parts = [
        _band(v.get("respiratory_rate"), [(8, 3), (11, 1), (20, 0), (24, 2)], 3),
        _band(v.get("spo2"), [(91, 3), (93, 2), (95, 1)], 0),
        _band(v.get("bp_systolic"), [(90, 3), (100, 2), (110, 1), (219, 0)], 3),
        _band(v.get("heart_rate"), [(40, 3), (50, 1), (90, 0), (110, 1), (130, 2)], 3),
        _band(v.get("temperature"), [(35.0, 3), (36.0, 1), (38.0, 0), (39.0, 1)], 2),
        (3 if v.get("alert") is False else 0) if v.get("alert") is not None else None,
    ]
    taken = [p for p in parts if p is not None]
    if len(taken) < 2:
        return None, False
    return sum(taken), any(p == 3 for p in taken)


_WARD_PREFS = {
    "urgent": ("resus", "emergency", "a&e", "casualty", "er", "icu"),
    "doctor": ("emergency", "a&e", "casualty", "er", "minors", "medical"),
    "routine": ("minors", "outpatient", "emergency", "er", "medical"),
}


def _level(triage_level: str) -> str:
    return triage_level if triage_level in ("urgent", "doctor") else "routine"


def suggest_ward(db: Session, hospital_id, triage_level: str) -> Optional[PortalWard]:
    wards = [w for w in db.query(PortalWard).filter(PortalWard.hospital_id == hospital_id)
             if w.beds_total - w.beds_occupied > 0]
    if not wards:
        return None
    for key in _WARD_PREFS[_level(triage_level)]:
        for w in wards:
            name = w.name.lower()
            if (name == key or name.startswith(key + " ") or f" {key}" in f" {name}") and (key != "icu" or w.critical):
                return w
    return max(wards, key=lambda w: w.beds_total - w.beds_occupied)


def active_case_counts(db: Session, hospital_id) -> Dict[str, int]:
    rows = (db.query(PortalCase.assignee_uid, func.count(PortalCase.id))
            .filter(PortalCase.hospital_id == hospital_id, PortalCase.status != "discharged",
                    PortalCase.assignee_uid.isnot(None))
            .group_by(PortalCase.assignee_uid).all())
    return {uid: n for uid, n in rows}


def suggest_assignee(db: Session, hospital_id, triage_level: str) -> Optional[StaffAccount]:
    """On-shift clinician with the fewest active patients; doctors first for
    urgent and doctor-level patients."""
    staff = db.query(StaffAccount).filter(
        StaffAccount.hospital_id == hospital_id, StaffAccount.status == StaffStatus.APPROVED,
        StaffAccount.on_duty.is_(True)).all()
    if not staff:
        return None
    if _level(triage_level) in ("urgent", "doctor"):
        doctors = [s for s in staff if s.role == StaffRole.DOCTOR]
        staff = doctors or staff
    load = active_case_counts(db, hospital_id)
    return min(staff, key=lambda s: (load.get(s.firebase_uid, 0), s.full_name or ""))
