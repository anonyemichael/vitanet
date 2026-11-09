# VitaNet hospital portal: what the model needs to do

This spec is for training the VitaNet model so it can take routine work off hospital staff in the portal. The portal will call the model once it is served. Until then, the portal uses simple rules and works without it.

There are five tasks. Each takes one JSON object and returns one JSON object. Train on the exact field names below, and the backend can call the model without any glue code.

## Ground rules for every task

1. **Use only what is in the input.** Never invent vitals, results, history, medicines or names. If something isn't in the input, leave it out or say it's unknown.
2. **Respect allergies.** Never suggest a drug, or a drug class, that the input's `allergies` rule out. If a common first-line drug is excluded, name the reason ("no penicillin — allergy").
3. **It's a suggestion, not an order.** Staff decide. Outputs are short checklists and drafts, never diagnoses stated as fact. Use "possible", "consider" and "rule out".
4. **Return valid JSON only.** No markdown and no extra text. Every listed key must be present. Use `[]` or `null` when a value is empty.
5. **Keep it short.** Staff read this on a phone during a shift. Use the limits given for each task.
6. **Patient-facing text** (task 3) is written at about a 12-year-old's reading level, in second person, with no abbreviations.
7. **Language:** English, in Ghanaian clinical context. Use local drug names where common (e.g. "Artemether-lumefantrine" for malaria) and Ghana emergency numbers (112, ambulance 193).

## Task 1: pre-arrival brief (`prep_brief`)

**When it runs:** a patient sends their summary to the hospital from VitaNet. The nurse sees the brief before the patient arrives.

**Input**
```json
{
  "task": "prep_brief",
  "triage_level": "urgent | doctor | pharmacist | self_care | routine",
  "age": 62, "sex": "male | female | null",
  "complaint": "Crushing chest pain, sweating",
  "triage_summary": "Started 40 min ago at rest, spreads to left arm.",
  "allergies": ["Penicillin"],
  "medications": ["Amlodipine 5 mg", "Aspirin 75 mg"],
  "conditions": ["Hypertension"],
  "vitals": {"heart_rate": 112, "bp_systolic": 162, "bp_diastolic": 98, "spo2": 95, "temperature": 36.9, "respiratory_rate": null},
  "eta_minutes": 6,
  "wards": [{"name": "Resus", "free": 2}, {"name": "Emergency", "free": 4}, {"name": "ICU", "free": 0}]
}
```

**Output**
```json
{
  "possible_conditions": ["Acute coronary syndrome", "Unstable angina"],
  "red_flags": ["Chest pain at rest radiating to arm", "HR 112", "BP 162/98"],
  "prepare": ["12-lead ECG on arrival", "Troponin", "IV access", "Aspirin 300 mg ready if not already taken", "Monitor and defibrillator nearby"],
  "avoid": ["Penicillin-class antibiotics (allergy)"],
  "suggested_ward": "Resus",
  "suggested_level": "urgent",
  "one_line": "62 M, likely cardiac chest pain, arrives in 6 min — ECG and troponin first."
}
```

**Limits**
- `possible_conditions`: at most 3.
- `prepare`: 3–6 items of at most 8 words each.
- `one_line`: at most 120 characters.
- `suggested_ward` must be a name from `wards` with `free > 0`, or `null`.
- `suggested_level` is one of `urgent`, `doctor` or `routine`. It may be higher than the patient's own triage when the vitals justify it, but never lower when the input says `urgent`.

## Task 2: triage check for walk-ins (`triage_check`)

**When it runs:** a nurse enters a walk-in, or re-triages someone in the waiting area.

**Input**
```json
{
  "task": "triage_check",
  "age": 9, "sex": "male",
  "complaint": "Fell from tree, forearm swollen and bent",
  "vitals": {"heart_rate": 118, "bp_systolic": null, "bp_diastolic": null, "spo2": 99, "temperature": 37.1, "respiratory_rate": 22, "pain": 8, "alert": true},
  "allergies": []
}
```

**Output**
```json
{
  "level": "doctor",
  "reasons": ["Deformed forearm — likely fracture", "Pain 8/10"],
  "red_flags_to_watch": ["Numb or cold fingers", "Open wound over the bone"],
  "first_steps": ["Splint the arm", "Pain relief", "X-ray forearm and wrist"]
}
```

**Limits**
- `level` is one of `urgent`, `doctor` or `routine`.
- Each list has at most 4 items.
- Any of these must give `urgent`: SpO₂ below 92, heart rate above 130 or below 40, systolic BP below 90, not alert, active seizure, signs of stroke, or major bleeding.

## Task 3: discharge summary for the patient (`discharge_draft`)

**When it runs:** a clinician presses "Draft from record". The clinician edits the draft before sending. The patient reads it in VitaNet under Visits.

**Input**
```json
{
  "task": "discharge_draft",
  "patient_name": "Yaw",
  "age": 62, "sex": "male",
  "complaint": "Chest pain",
  "outcome": "home | admitted | transferred | left",
  "admitted_to": "Cardiology ward",
  "allergies": ["Penicillin"],
  "timeline": [
    {"at": "09:47", "kind": "referral", "text": "Accepted VitaNet referral (urgent)"},
    {"at": "09:58", "kind": "prescription", "text": "Rx: Aspirin 300 mg (once)"},
    {"at": "10:12", "kind": "vitals", "text": "HR 108, BP 158/96, SpO2 96%"},
    {"at": "10:40", "kind": "note", "text": "Troponin raised. NSTEMI. Heparin started. Cardiology to review for angiography."}
  ],
  "latest_vitals": {"heart_rate": 92, "bp_systolic": 140, "bp_diastolic": 88, "spo2": 97}
}
```

**Output**
```json
{
  "summary": "You had a heart attack caused by a partly blocked blood vessel. We gave you aspirin and a blood thinner, and your heart rate and blood pressure are settling.",
  "what_next": "You are staying on the cardiology ward. The heart team will check your blood vessels with a special X-ray.",
  "medicines": ["Keep taking amlodipine", "Aspirin every day"],
  "warning_signs": ["Chest pain that comes back", "Trouble breathing", "Fainting"],
  "follow_up": null
}
```

**Limits**
- Each text field is at most 3 sentences.
- Mention only medicines that appear in the timeline or the input.
- `warning_signs` has 2–4 items, each meaning "come back or call 112 if…".
- For outcome `left`, gently tell them to come back if they get worse.

## Task 4: shift handover note (`handover_note`)

**When it runs:** a clinician ends their shift and hands over their patients. One note is written per patient and added to that patient's timeline.

**Input**
```json
{
  "task": "handover_note",
  "patient": {"name": "Kwame Mensah", "age": 56, "sex": "male", "level": "urgent", "status": "treatment", "ward": "Emergency", "bed": "7"},
  "complaint": "Short of breath",
  "allergies": [],
  "timeline": [{"at": "08:10", "kind": "note", "text": "Wheeze both sides. Salbutamol nebs x2."}, {"at": "09:30", "kind": "vitals", "text": "RR 24, SpO2 93%"}],
  "latest_vitals": {"respiratory_rate": 24, "spo2": 93, "heart_rate": 104},
  "early_warning_score": 5,
  "to": "Dr. Ama Addo"
}
```

**Output**
```json
{
  "situation": "56 M, short of breath, ER bed 7, in treatment.",
  "background": "Wheeze both sides; 2 salbutamol nebs given from 08:10.",
  "assessment": "Still working to breathe: RR 24, SpO₂ 93%, early-warning score 5.",
  "recommendation": "Recheck obs within 30 min; escalate to senior if SpO₂ under 92.",
  "pending": ["Response to nebs"]
}
```

**Limits**
- Each field is at most 160 characters.
- `pending` lists only things the timeline shows as ordered or awaited, and is empty if there are none.

## Task 5: tidy a dictated note (`structure_note`) — optional, lower priority

**When it runs:** a staff member types or dictates a quick note. The model pulls out any structured values so they can be saved as vitals and orders after one tap to confirm.

**Input**
```json
{"task": "structure_note", "text": "pt more settled, hr 96 bp 138 over 85 sats 97 on air, given paracetamol 1g iv"}
```

**Output**
```json
{
  "clean_text": "Patient more settled. HR 96, BP 138/85, SpO₂ 97% on air. Paracetamol 1 g IV given.",
  "vitals": {"heart_rate": 96, "bp_systolic": 138, "bp_diastolic": 85, "spo2": 97, "temperature": null, "respiratory_rate": null},
  "medications_given": [{"name": "Paracetamol", "dose": "1 g", "route": "IV"}]
}
```

## How the portal will call the model

- **Endpoint:** an OpenAI-compatible `POST {PORTAL_AI_URL}/chat/completions`, with `model = PORTAL_AI_MODEL` and an optional bearer `PORTAL_AI_KEY`. vLLM, Ollama, TGI and LM Studio all serve this.
- **Messages:** one system message (the ground rules above plus the task's limits) and one user message holding the input JSON. The `task` field says which of the five tasks it is.
- **Request settings:** `temperature` 0.2, `max_tokens` 600, `response_format: {"type": "json_object"}` when supported.
- **Timeout:** 20 s. On a timeout, invalid JSON or a missing key, the portal discards the answer and shows its rule-based version instead, so staff are never blocked.
- **Labelling and logging:** the portal labels every output "AI suggestion" and records in the audit log that AI was used. It never sends anything the patient didn't consent to share.

## Training data tips

- **Source:** de-identified ED records, plus synthetic cases written or checked by clinicians. Cover Ghana's common presentations: malaria, sickle cell crisis, hypertension and stroke, road traffic injuries, pregnancy complications, pneumonia, gastroenteritis in children, diabetes emergencies and snake bite.
- **Negative examples:**
  - inputs that are missing fields, where the right answer is `null` or `[]`
  - an allergy that rules out the usual drug
  - a vague complaint ("not feeling well") with normal vitals, where the right level is `routine`
- **Format:** each training row is the user JSON paired with the assistant JSON. `docs/portal-ai-training-examples.jsonl` has starter rows in chat format.
- **Evaluation to run before plugging it in:**
  - JSON validity at least 99%
  - no invented values (check every number in the output appears in the input)
  - zero allergy violations
  - triage `urgent` recall at least 95% on red-flag cases
  - clinician rating of the drafts
