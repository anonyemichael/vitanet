# app/services/portal_ai.py
"""The 5 hospital-portal model tasks (prep_brief, triage_check, discharge_draft, handover_note, structure_note).

Serving contract (docs/portal-ai-model-spec.md): OpenAI-compatible POST {PORTAL_AI_URL}/chat/completions, one
system message (rules + task limits) and one user message (the input JSON), temperature 0.2, max_tokens 600,
response_format json_object, 20 s timeout. Every model answer is checked with portal_checks.check (valid JSON, every
key, no invented numbers, no allergy violations, hard-rule urgent, ward with free beds). If the model is not
configured, times out, or fails a check, the portal gets the RULE-BASED answer below instead, so staff always get
something safe. Callers must label model output "AI suggestion" and audit-log it.
"""
import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, Tuple

import httpx

from app.core.config import settings
from app.services import portal_rules
from app.services.portal_checks import SCHEMAS, _triage_must_be_urgent, check

logger = logging.getLogger(__name__)
SYSTEM_PROMPT = Path(__file__).with_name("portal_system_prompt.txt").read_text(encoding="utf-8")
TASKS = set(SCHEMAS)
RANK = {"routine": 0, "doctor": 1, "urgent": 2}


# ---------------------------------------------------------------- rule-based fallbacks (no AI)
def _vital_flags(v: Dict[str, Any]) -> list:
    out = []
    if (v.get("spo2") or 100) < 92:
        out.append(f"SpO2 {v['spo2']}")
    hr = v.get("heart_rate")
    if hr is not None and (hr > 130 or hr < 40):
        out.append(f"HR {hr}")
    if v.get("bp_systolic") is not None and v["bp_systolic"] < 90:
        out.append(f"BP {v['bp_systolic']}/{v.get('bp_diastolic')}")
    if v.get("alert") is False:
        out.append("Not alert")
    return out


def _level(inp: Dict[str, Any], given: str = "routine") -> str:
    lv = given if given in RANK else "routine"
    if _triage_must_be_urgent(inp):
        lv = "urgent"
    score, red = portal_rules.early_warning(inp.get("vitals") or {})
    if score is not None and (score >= portal_rules.EARLY_WARNING_ALERT or red) and RANK[lv] < 2:
        lv = "urgent" if score >= 7 else "doctor"
    return lv


def fallback(inp: Dict[str, Any]) -> Dict[str, Any]:
    task = inp.get("task")
    v = inp.get("vitals") or inp.get("latest_vitals") or {}
    allergies = inp.get("allergies") or []
    avoid = [f"{a} (allergy)" for a in allergies]
    if task == "triage_check":
        lv = _level(inp)
        return {"level": lv, "reasons": (_vital_flags(v) or ["No hard-rule red flag in the observations"])[:4],
                "red_flags_to_watch": ["Falling oxygen or consciousness", "New chest pain or breathlessness"],
                "first_steps": ["Full set of observations", "Clinician review"] if lv != "urgent"
                else ["Move to resuscitation area", "Call the doctor now"]}
    if task == "prep_brief":
        lv = _level(inp, inp.get("triage_level", "routine"))
        free = [w["name"] for w in inp.get("wards") or [] if (w.get("free") or 0) > 0]
        prefs = {"urgent": ("Resus", "Emergency"), "doctor": ("Emergency",), "routine": ("Outpatients", "Emergency")}[lv]
        ward = next((w for p in prefs for w in free if w.lower().startswith(p.lower())), free[0] if free else None)
        return {"possible_conditions": [], "red_flags": _vital_flags(v),
                "prepare": ["Full observations on arrival", "Review allergies and medicines", "IV access if unwell"],
                "avoid": avoid, "suggested_ward": ward, "suggested_level": lv,
                "one_line": f"{inp.get('age', '')} {str(inp.get('sex') or '')[:1].upper()}, {inp.get('complaint', '')}"[:120]}
    if task == "discharge_draft":
        return {"summary": "You were seen at the hospital today.",
                "what_next": "Follow the advice the clinic gave you and take your medicines as explained.",
                "medicines": [], "warning_signs": ["Come back or call 112 if you feel much worse.",
                                                   "Come back or call 112 if you have trouble breathing."],
                "follow_up": None}
    if task == "handover_note":
        p = inp.get("patient") or {}
        pending = [e.get("text") for e in inp.get("timeline") or [] if e.get("kind") in ("ordered", "awaiting")]
        return {"situation": f"{p.get('age', '')} {str(p.get('sex') or '')[:1].upper()}, {p.get('ward', '')} bed "
                             f"{p.get('bed', '')}: {inp.get('complaint', '')}"[:160],
                "background": f"Allergies: {', '.join(allergies) or 'none known'}."[:160],
                "assessment": f"Early warning score {inp.get('early_warning_score')}."[:160],
                "recommendation": "Review observations and escalate if the warning score rises."[:160],
                "pending": [x for x in pending if x]}
    if task == "structure_note":
        text = inp.get("text") or ""
        grab = lambda pat: (float(m.group(1)) if (m := re.search(pat, text, re.I)) else None)
        bp = re.search(r"\bBP\s*(\d{2,3})\s*/\s*(\d{2,3})", text, re.I)
        vit = {"heart_rate": grab(r"\b(?:HR|pulse)\s*(\d{2,3})"), "bp_systolic": float(bp.group(1)) if bp else None,
               "bp_diastolic": float(bp.group(2)) if bp else None, "spo2": grab(r"\bSpO2\s*(\d{2,3})"),
               "temperature": grab(r"\bT(?:emp)?\s*(\d{2}(?:\.\d)?)"), "respiratory_rate": grab(r"\bRR\s*(\d{1,2})")}
        return {"clean_text": text, "vitals": vit, "medications_given": []}
    raise ValueError(f"unknown task {task!r}")


# ---------------------------------------------------------------- model call
def _call_model(inp: Dict[str, Any], client=None) -> str:
    url = settings.PORTAL_AI_URL.rstrip("/") + "/chat/completions"
    body = {"model": settings.PORTAL_AI_MODEL, "temperature": 0.2, "max_tokens": 600,
            "response_format": {"type": "json_object"},
            "messages": [{"role": "system", "content": SYSTEM_PROMPT},
                         {"role": "user", "content": json.dumps(inp, ensure_ascii=False)}]}
    headers = {"Authorization": f"Bearer {settings.PORTAL_AI_KEY}"} if settings.PORTAL_AI_KEY else {}
    http = client or httpx.Client(timeout=settings.PORTAL_AI_TIMEOUT_S)
    r = http.post(url, json=body, headers=headers)
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"] or ""


def run_task(inp: Dict[str, Any], client=None) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """(output, info). info["source"] is "ai" when the model's answer passed every check, else "rules"."""
    task = inp.get("task")
    if task not in TASKS:
        raise ValueError(f"unknown task {task!r}")
    if not settings.PORTAL_AI_URL:
        return fallback(inp), {"source": "rules", "reason": "PORTAL_AI_URL not set"}
    try:
        text = _call_model(inp, client)
    except Exception as e:
        logger.warning("portal model call failed (%s): %s", task, e)
        return fallback(inp), {"source": "rules", "reason": f"model unavailable: {type(e).__name__}"}
    errors = check(inp, text)
    if errors:
        logger.info("portal model answer rejected (%s): %s", task, errors[:3])
        return fallback(inp), {"source": "rules", "reason": "model answer failed checks", "errors": errors[:5]}
    return json.loads(text), {"source": "ai", "label": "AI suggestion"}
