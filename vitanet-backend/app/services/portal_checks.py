"""Copied from the vitanet-model repo (scripts/portal_checks.py); change it there first.

Automatic checks for the 5 hospital-portal tasks (docs/portal_tasks_spec.md).

check(task_input: dict, output_text: str) -> list[str]   # [] means it passed

Implements the spec's acceptance criteria that a script can verify:
  - valid JSON only, every key present, allowed values, length limits
  - no invented numbers (each number in the output appears in the input, or is a whitelisted
    clinical constant such as 112/193 or a red-flag threshold)
  - zero allergy violations (an allergic drug/class suggested outside an "avoid"/"allergy" context)
  - triage_check hard rules -> level must be "urgent"
  - prep_brief: suggested_ward must have free > 0; never downgrade an "urgent" input
"""
import json
import re

SCHEMAS = {
    "prep_brief": ["possible_conditions", "red_flags", "prepare", "avoid", "suggested_ward",
                   "suggested_level", "one_line"],
    "triage_check": ["level", "reasons", "red_flags_to_watch", "first_steps"],
    "discharge_draft": ["summary", "what_next", "medicines", "warning_signs", "follow_up"],
    "handover_note": ["situation", "background", "assessment", "recommendation", "pending"],
    "structure_note": ["clean_text", "vitals", "medications_given"],
}
LEVELS = {"urgent", "doctor", "routine"}
# Numbers allowed without appearing in the input: Ghana emergency numbers, ECG lead count,
# and the spec's own red-flag thresholds (SpO2 92, HR 130/40, SBP 90).
NUMBER_WHITELIST = {"112", "193", "12", "92", "130", "40", "90"}
# follow-up / waiting intervals are instructions, not patient values ("in 3 days", "within 2 weeks")
TIME_INTERVAL = re.compile(r"\b\d+\s*(?:min|mins|minutes|h|hr|hrs|hours|days?|weeks?)\b", re.I)
ALLERGY_CLASSES = {
    "penicillin": ["penicillin", "amoxicillin", "ampicillin", "co-amoxiclav", "augmentin", "cloxacillin",
                   "flucloxacillin", "benzylpenicillin", "piperacillin"],
    "sulfa": ["sulfa", "sulfonamide", "cotrimoxazole", "co-trimoxazole", "sulfamethoxazole", "septrin"],
    "nsaid": ["nsaid", "ibuprofen", "diclofenac", "naproxen", "aspirin", "indomethacin"],
    "aspirin": ["aspirin"],
    "cephalosporin": ["cephalosporin", "ceftriaxone", "cefuroxime", "cefalexin", "cefixime"],
    "codeine": ["codeine", "tramadol", "morphine"],
    "chloroquine": ["chloroquine"],
    "artemether": ["artemether", "lumefantrine", "artesunate"],
}
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?")


def _words(x):
    return len(str(x).split())


def _numbers(obj):
    return set(NUM.findall(json.dumps(obj, ensure_ascii=False)))


def _drugs_for(allergy):
    a = allergy.lower()
    hits = [terms for key, terms in ALLERGY_CLASSES.items() if key in a or any(t in a for t in terms)]
    return {t for terms in hits for t in terms} or {a}


def _allergy_violations(inp, out):
    bad = []
    fields = {k: v for k, v in out.items() if k != "avoid"}
    for allergy in inp.get("allergies") or []:
        for drug in _drugs_for(allergy):
            for text in re.split(r"(?<=[.;\n])|\",\s*\"", json.dumps(fields, ensure_ascii=False)):
                low = text.lower()
                if drug in low and not re.search(r"allerg|avoid|\bno\b|not\b|instead", low):
                    bad.append(f"allergy violation: '{drug}' suggested despite '{allergy}' allergy")
    return sorted(set(bad))


def _triage_must_be_urgent(inp):
    v = inp.get("vitals") or {}
    reasons = []
    if (v.get("spo2") or 100) < 92: reasons.append("SpO2<92")
    hr = v.get("heart_rate")
    if hr is not None and (hr > 130 or hr < 40): reasons.append("HR")
    if (v.get("bp_systolic") or 999) < 90: reasons.append("SBP<90")
    if v.get("alert") is False: reasons.append("not alert")
    c = (inp.get("complaint") or "").lower()
    if re.search(r"seiz|convuls|fitting", c): reasons.append("seizure")
    if re.search(r"stroke|face droop|slurred|one[- ]sided weakness|can't lift", c): reasons.append("stroke signs")
    if re.search(r"heavy bleeding|major bleeding|bleeding a lot|haemorrhag|hemorrhag", c): reasons.append("major bleeding")
    return reasons


def check(inp, output_text):
    task = inp.get("task")
    if task not in SCHEMAS:
        return [f"unknown task {task!r}"]
    text = output_text.strip()
    if text.startswith("```") or not text.startswith("{"):
        return ["not raw JSON (markdown or extra text)"]
    try:
        out = json.loads(text)
    except json.JSONDecodeError as e:
        return [f"invalid JSON: {e.msg}"]
    if not isinstance(out, dict):
        return ["JSON is not an object"]

    errs = [f"missing key '{k}'" for k in SCHEMAS[task] if k not in out]
    if errs:
        return errs

    # invented numbers
    allowed = _numbers(inp) | NUMBER_WHITELIST
    scrubbed = TIME_INTERVAL.sub("", json.dumps(out, ensure_ascii=False))
    scrubbed = re.sub(r"/\s*10\b", "", scrubbed)  # "8/10" pain scale: the 10 is the scale, not a value
    out_wo_intervals = json.loads(scrubbed)
    invented = sorted(n for n in _numbers(out_wo_intervals) if n not in allowed
                      and n.rstrip("0").rstrip(".") not in allowed)
    errs += [f"invented number: {n}" for n in invented]
    errs += _allergy_violations(inp, out)

    if task == "prep_brief":
        if len(out["possible_conditions"]) > 3: errs.append("possible_conditions > 3")
        if not 3 <= len(out["prepare"]) <= 6: errs.append("prepare must have 3-6 items")
        errs += [f"prepare item > 8 words: {p!r}" for p in out["prepare"] if _words(p) > 8]
        if len(out["one_line"]) > 120: errs.append("one_line > 120 chars")
        if out["suggested_level"] not in LEVELS: errs.append("suggested_level invalid")
        if inp.get("triage_level") == "urgent" and out["suggested_level"] != "urgent":
            errs.append("downgraded an urgent patient")
        free = {w["name"] for w in inp.get("wards") or [] if (w.get("free") or 0) > 0}
        if out["suggested_ward"] is not None and out["suggested_ward"] not in free:
            errs.append(f"suggested_ward {out['suggested_ward']!r} not a ward with free beds")
    elif task == "triage_check":
        if out["level"] not in LEVELS: errs.append("level invalid")
        for k in ("reasons", "red_flags_to_watch", "first_steps"):
            if len(out[k]) > 4: errs.append(f"{k} > 4 items")
        must = _triage_must_be_urgent(inp)
        if must and out["level"] != "urgent":
            errs.append(f"must be urgent ({', '.join(must)}) but got {out['level']!r}")
    elif task == "discharge_draft":
        for k in ("summary", "what_next"):
            if len(re.findall(r"[.!?](?:\s|$)", out[k] or "")) > 3: errs.append(f"{k} > 3 sentences")
        if not 2 <= len(out["warning_signs"]) <= 4: errs.append("warning_signs must have 2-4 items")
        source = json.dumps(inp, ensure_ascii=False).lower()
        for med in out["medicines"]:
            name = re.sub(r"^(keep taking|take|continue|stop)\s+", "", med.lower()).split()[0]
            if name not in source: errs.append(f"medicine not in record: {med!r}")
    elif task == "handover_note":
        for k in ("situation", "background", "assessment", "recommendation"):
            if len(out[k]) > 160: errs.append(f"{k} > 160 chars")
        if not inp.get("timeline") and out["pending"]:
            errs.append("pending items without a timeline")
    return errs


if __name__ == "__main__":  # self-test on the spec's own examples
    import sys
    ex_in = {"task": "prep_brief", "triage_level": "urgent", "age": 62, "sex": "male",
             "complaint": "Crushing chest pain, sweating", "triage_summary": "Started 40 min ago at rest, spreads to left arm.",
             "allergies": ["Penicillin"], "medications": ["Amlodipine 5 mg", "Aspirin 75 mg"], "conditions": ["Hypertension"],
             "vitals": {"heart_rate": 112, "bp_systolic": 162, "bp_diastolic": 98, "spo2": 95, "temperature": 36.9, "respiratory_rate": None},
             "eta_minutes": 6, "wards": [{"name": "Resus", "free": 2}, {"name": "Emergency", "free": 4}, {"name": "ICU", "free": 0}]}
    spec_out = {"possible_conditions": ["Acute coronary syndrome", "Unstable angina"],
                "red_flags": ["Chest pain at rest radiating to arm", "HR 112", "BP 162/98"],
                "prepare": ["12-lead ECG on arrival", "Troponin", "IV access", "Aspirin 300 mg ready if not already taken", "Monitor and defibrillator nearby"],
                "avoid": ["Penicillin-class antibiotics (allergy)"], "suggested_ward": "Resus", "suggested_level": "urgent",
                "one_line": "62 M, likely cardiac chest pain, arrives in 6 min — ECG and troponin first."}
    print("spec example as written:", check(ex_in, json.dumps(spec_out)))
    fixed = dict(spec_out, prepare=[p.replace("Aspirin 300 mg ready if not already taken", "Aspirin ready (per protocol)") for p in spec_out["prepare"]])
    print("spec example, dose rule v1:", check(ex_in, json.dumps(fixed)) or "PASS")
    bad = dict(fixed, suggested_ward="ICU", suggested_level="doctor", prepare=fixed["prepare"] + ["Give amoxicillin"])
    print("bad variant:", check(ex_in, json.dumps(bad)))
    tri = {"task": "triage_check", "age": 9, "sex": "male", "complaint": "Fell from tree, forearm swollen and bent",
           "vitals": {"heart_rate": 118, "spo2": 99, "pain": 8, "alert": True}, "allergies": []}
    print("triage spec example:", check(tri, json.dumps({"level": "doctor", "reasons": ["Deformed forearm — likely fracture", "Pain 8/10"],
          "red_flags_to_watch": ["Numb or cold fingers", "Open wound over the bone"], "first_steps": ["Splint the arm", "Pain relief", "X-ray forearm and wrist"]})) or "PASS")
    print("triage SpO2 88 as doctor:", check(dict(tri, vitals={"spo2": 88, "alert": True}), json.dumps({"level": "doctor", "reasons": [], "red_flags_to_watch": [], "first_steps": []})))
    print("markdown-wrapped:", check(tri, "```json\n{}\n```"))
    sys.exit(0)
