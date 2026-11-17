# app/services/portal_tools.py
"""Hospital-facing toolbox (docs/AI_MODEL_INTEGRATION_PLAN.md section 3).

Deterministic tools (no AI; always available, always the same answer for the same input):
  calculate_news2_score, check_ward_capacity, balance_clinician_workload, allergy_prescription_guard
Model-backed tools (the VitaNet model, with a rule-based fallback; see portal_ai.py):
  prep_brief_copilot, walkin_triage_checker, generate_sbar_handover, structure_clinical_notes, discharge_draft
"""
import re
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.portal import PortalWard
from app.services import portal_rules
from app.services.portal_checks import ALLERGY_CLASSES

# Extra brand / local names so the guard catches what staff actually type (classes from portal_checks.py)
_EXTRA_NAMES = {
    "penicillin": ["amoxiclav", "clavulanate", "amoksiklav", "pen v", "pen-v", "phenoxymethylpenicillin"],
    "nsaid": ["brufen", "voltaren", "cataflam", "mefenamic", "ponstan", "ketorolac", "piroxicam", "meloxicam"],
    "sulfa": ["bactrim", "sulfadoxine", "fansidar"],
    "artemether": ["coartem", "lonart", "artemisinin", "dihydroartemisinin", "amodiaquine"],
}


def calculate_news2_score(vitals: Dict[str, Any]) -> Dict[str, Any]:
    """NEWS2-style early warning score (portal_rules.early_warning). Needs at least two observations."""
    score, red = portal_rules.early_warning(vitals or {})
    return {
        "score": score,
        "any_single_parameter_3": red,
        "alert": bool(score is not None and (score >= portal_rules.EARLY_WARNING_ALERT or red)),
        "note": None if score is not None else "Fewer than two observations: no score",
    }


def check_ward_capacity(db: Session, hospital_id) -> List[Dict[str, Any]]:
    wards = db.query(PortalWard).filter(PortalWard.hospital_id == hospital_id).all()
    return [{"name": w.name, "free": max(0, w.beds_total - w.beds_occupied), "total": w.beds_total,
             "critical": w.critical} for w in wards]


def balance_clinician_workload(db: Session, hospital_id, triage_level: str) -> Dict[str, Any]:
    pick = portal_rules.suggest_assignee(db, hospital_id, triage_level)
    load = portal_rules.active_case_counts(db, hospital_id)
    if not pick:
        return {"suggested": None, "note": "No approved clinician is on duty"}
    return {"suggested": {"uid": pick.firebase_uid, "name": pick.full_name, "role": pick.role.value,
                          "active_patients": load.get(pick.firebase_uid, 0)}}


def _drug_terms(allergy: str) -> Dict[str, set]:
    """Allergy as written -> {class: names in that class} (falls back to the allergy word itself)."""
    a = allergy.strip().lower()
    out = {}
    for key, terms in ALLERGY_CLASSES.items():
        names = set(terms) | set(_EXTRA_NAMES.get(key, []))
        if key in a or any(t in a for t in names):
            out[key] = names
    return out or {a: {a}}


def allergy_prescription_guard(drug: str, allergies: List[str]) -> Dict[str, Any]:
    """Is `drug` safe for a patient with these allergies? Matches drug FAMILIES, not only the exact word:
    an allergy to "penicillin" blocks amoxicillin, Augmentin, cloxacillin, ... (the old check only blocked drugs
    whose name contained the allergy word, so "penicillin" let amoxicillin through)."""
    d = re.sub(r"\s+", " ", (drug or "").lower())
    for allergy in allergies or []:
        if not allergy or not allergy.strip():
            continue
        for cls, names in _drug_terms(allergy).items():
            hit = next((n for n in sorted(names, key=len, reverse=True) if n and n in d), None)
            if hit:
                return {"allowed": False, "allergy": allergy.strip(), "drug_class": cls,
                        "reason": f"{drug} is in the {cls} family; the patient is allergic to {allergy.strip()}"}
    return {"allowed": True, "allergy": None, "drug_class": None, "reason": None}


def parse_allergies(text: Optional[str]) -> List[str]:
    return [a.strip() for a in re.split(r"[,;/\n]", text or "") if a.strip()]
