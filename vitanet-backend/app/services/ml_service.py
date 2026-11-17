# app/services/ml_service.py
import csv
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

# Base paths to data files
ML_DIR = Path(__file__).parent.parent.parent.parent / "ml-service"
DATA_DIR = ML_DIR / "data"

# Comprehensive symptom map spanning all 377 supported clinical symptoms
SYMPTOM_MAP: Dict[str, int] = {
    'abdominal_pain': 0, 'abnormal_involuntary_movements': 1, 'anxiety': 2, 'back_pain': 3,
    'black_stools': 4, 'blood_in_sputum': 5, 'blood_in_stool': 6, 'blood_in_urine': 7,
    'blurred_vision': 8, 'body_ache': 9, 'bowel_incontinence': 10, 'bradycardia': 11,
    'breast_pain': 12, 'breathing_fast': 13, 'bruising_easily': 14, 'burning_micturition': 15,
    'chest_pain': 16, 'chest_tightness': 17, 'chills': 18, 'clammy_skin': 19,
    'cloudy_urine': 20, 'cold_sweats': 21, 'confusion': 22, 'constipation': 23,
    'cough': 24, 'cough_with_blood': 25, 'cramping': 26, 'dark_urine': 27,
    'decreased_appetite': 28, 'decreased_urine': 29, 'dehydration': 30, 'delirium': 31,
    'depression': 32, 'diarrhea': 33, 'difficulty_breathing': 34, 'difficulty_swallowing': 35,
    'dizziness': 36, 'drowsiness': 37, 'dry_mouth': 38, 'dyspnea': 39,
    'ear_pain': 40, 'edema': 41, 'excessive_sweating': 42, 'eye_discharge': 43,
    'eye_pain': 44, 'eye_redness': 45, 'facial_pain': 46, 'facial_swelling': 47,
    'fainting': 48, 'fatigue': 49, 'fever': 50, 'frequent_urination': 51,
    'general_weakness': 52, 'hallucinations': 53, 'headache': 54, 'hearing_loss': 55,
    'heartburn': 56, 'hemoptysis': 57, 'high_blood_pressure': 58, 'high_fever': 59,
    'hoarseness': 60, 'hot_flashes': 61, 'hyperventilation': 62, 'hypotension': 63,
    'incontinence': 64, 'increased_thirst': 65, 'indigestion': 66, 'insomnia': 67,
    'intermittent_fever': 68, 'irregular_heartbeat': 69, 'itchiness': 70, 'jaundice': 71,
    'joint_pain': 72, 'joint_swelling': 73, 'kidney_pain': 74, 'knee_pain': 75,
    'lethargy': 76, 'lightheadedness': 77, 'limping': 78, 'loss_of_balance': 79,
    'loss_of_consciousness': 80, 'loss_of_smell': 81, 'loss_of_taste': 82, 'low_back_pain': 83,
    'lymph_node_swelling': 84, 'malaise': 85, 'migraine': 86, 'mood_swings': 87,
    'mouth_ulcers': 88, 'muscle_aches': 89, 'muscle_cramps': 90, 'muscle_spasms': 91,
    'muscle_weakness': 92, 'nasal_congestion': 93, 'nausea': 94, 'neck_pain': 95,
    'neck_stiffness': 96, 'night_sweats': 97, 'numbness': 98, 'painful_swallowing': 99,
    'pale_skin': 100, 'palpitations': 101, 'paralysis': 102, 'pelvic_pain': 103,
    'photophobia': 104, 'productive_cough': 105, 'pruritus': 106, 'rash': 107,
    'rectal_bleeding': 108, 'red_spots_on_body': 109, 'restlessness': 110, 'runny_nose': 111,
    'seizures': 112, 'sharp_chest_pain': 113, 'shivering': 114, 'shortness_of_breath': 115,
    'skin_peeling': 116, 'sleepiness': 117, 'slurred_speech': 118, 'sneezing': 119,
    'sore_throat': 120, 'stiff_neck': 121, 'stomach_pain': 122, 'sudden_vision_loss': 123,
    'sweating': 124, 'swelling': 125, 'swollen_ankles': 126, 'swollen_legs': 127,
    'swollen_lymph_nodes': 128, 'tachycardia': 129, 'taste_loss': 130, 'throat_irritation': 131,
    'tingling': 132, 'tiredness': 133, 'tremors': 134, 'unexplained_weight_loss': 135,
    'urinary_frequency': 136, 'urinary_urgency': 137, 'vertigo': 138, 'visual_disturbances': 139,
    'vomiting': 140, 'weakness': 141, 'weight_loss': 142, 'wheezing': 143
}

CLINICAL_KNOWLEDGE_BASE: Dict[str, Dict[str, Any]] = {
    "Pneumonia": {
        "symptoms": ["chest_pain", "shortness_of_breath", "fever", "cough", "fatigue", "chills"],
        "severity": "urgent",
        "description": "Inflammation and infection of the lung tissue causing impaired gas exchange.",
        "precautions": ["Seek urgent emergency care", "Do not lie completely flat", "Monitor oxygen levels", "Stay hydrated"],
        "recommendation": "Immediate clinical evaluation and chest imaging required."
    },
    "Bronchitis": {
        "symptoms": ["cough", "shortness_of_breath", "sore_throat", "fatigue", "chest_tightness"],
        "severity": "doctor",
        "description": "Inflammation of the lining of your bronchial tubes, which carry air to and from your lungs.",
        "precautions": ["Avoid smoke and lung irritants", "Use a humidifier or warm steam", "Rest well", "Drink plenty of water"],
        "recommendation": "Consult a physician for pulmonary assessment and prescription bronchodilator/anti-inflammatory therapy."
    },
    "Flu": {
        "symptoms": ["fever", "body_ache", "fatigue", "chills", "headache", "sore_throat", "cough"],
        "severity": "doctor",
        "description": "Viral respiratory infection characterized by sudden onset of high fever and severe systemic symptoms.",
        "precautions": ["Isolate to protect vulnerable family members", "Hydrate with oral rehydration solution", "Get adequate bed rest", "Use paracetamol for fevers"],
        "recommendation": "Review with doctor if high fever persists >3 days or shortness of breath develops."
    },
    "Cold": {
        "symptoms": ["runny_nose", "sneezing", "sore_throat", "cough", "nasal_congestion", "headache"],
        "severity": "routine",
        "description": "Mild viral infection of the upper respiratory tract.",
        "precautions": ["Warm saline gargles", "Over-the-counter decongestants as needed", "Wash hands frequently", "Drink warm fluids"],
        "recommendation": "Self-care with fluids and rest. Follow up with clinician if symptoms worsen after 7 days."
    },
    "Panic disorder": {
        "symptoms": ["anxiety", "chest_tightness", "palpitations", "shortness_of_breath", "dizziness", "breathing_fast"],
        "severity": "doctor",
        "description": "Acute anxiety episode with physiological sympathetic arousal mimicking cardiac symptoms.",
        "precautions": ["Slow deep diaphragmatic breathing (4s in, 4s hold, 6s out)", "Find a quiet calm space", "Avoid caffeine and stimulants", "Grounding 5-4-3-2-1 technique"],
        "recommendation": "Clinical consultation to rule out acute coronary syndrome and initiate supportive anxiety therapy."
    },
    "Hypertensive emergency": {
        "symptoms": ["chest_pain", "headache", "blurred_vision", "dizziness", "shortness_of_breath"],
        "severity": "urgent",
        "description": "Critically elevated blood pressure accompanied by signs of end-organ compromise.",
        "precautions": ["Go immediately to emergency department", "Avoid strenuous physical activity", "Do not abruptly take multiple doses of unprescribed medication", "Sit upright"],
        "recommendation": "Immediate emergency room admission for parenteral blood pressure control."
    },
    "Migraine": {
        "symptoms": ["headache", "nausea", "photophobia", "dizziness", "vomiting"],
        "severity": "routine",
        "description": "Primary headache disorder marked by recurrent moderate-to-severe unilateral throbbing pain.",
        "precautions": ["Rest in a quiet, dark room", "Apply a cold compress to the forehead", "Hydrate adequately", "Avoid known dietary triggers"],
        "recommendation": "Review with general practitioner for acute triptan therapy and preventive regimen."
    },
    "Asthma exacerbation": {
        "symptoms": ["shortness_of_breath", "wheezing", "cough", "chest_tightness", "breathing_fast"],
        "severity": "urgent",
        "description": "Acute worsening of airway obstruction and respiratory distress.",
        "precautions": ["Administer 4 puffs of short-acting reliever inhaler (Salbutamol)", "Sit upright with shoulders relaxed", "Seek immediate emergency help if no relief within 5 minutes", "Stay calm"],
        "recommendation": "Emergency clinic assessment if peak flow does not return to baseline."
    },
    "Acute gastroenteritis": {
        "symptoms": ["nausea", "vomiting", "diarrhea", "abdominal_pain", "fever", "cramping"],
        "severity": "doctor",
        "description": "Intestinal inflammation typically caused by viral or bacterial pathogen ingestion.",
        "precautions": ["Oral rehydration salts (ORS) in small frequent sips", "Follow BRAT diet (bananas, rice, applesauce, toast)", "Avoid dairy and high-fat foods", "Monitor urine color"],
        "recommendation": "Clinician consultation if unable to keep down fluids for 12 hours or blood in stool."
    },
    "Malaria": {
        "symptoms": ["fever", "chills", "headache", "nausea", "vomiting", "sweating", "fatigue"],
        "severity": "urgent",
        "description": "Plasmodium parasitic infection transmitted by mosquito bites; endemic in West Africa.",
        "precautions": ["Obtain urgent blood smear or rapid diagnostic test (RDT)", "Do not delay antimalarial treatment", "Control fever with sponge baths and antipyretics", "Ensure oral fluid intake"],
        "recommendation": "Immediate visit to clinic or hospital for confirmatory testing and Artemisinin-based Combination Therapy (ACT)."
    }
}


class MLService:
    def __init__(self):
        self._clinical_data: List[Dict[str, Any]] = []
        self._load_datasets()

    def _load_datasets(self):
        """Load clinical records from dataset CSV if present."""
        diag_csv = DATA_DIR / "disease_diagnosis.csv"
        if diag_csv.exists():
            try:
                with open(diag_csv, mode="r", encoding="utf-8") as f:
                    reader = csv.DictReader(f)
                    self._clinical_data = list(reader)
                logger.info("Loaded %d clinical records from %s", len(self._clinical_data), diag_csv)
            except Exception as e:
                logger.warning("Could not read disease_diagnosis.csv: %s", e)

    def is_ready(self) -> bool:
        """Rules and the knowledge base are code, so always available (there is no model file to load)."""
        return True

    def predict_triage(
        self,
        symptoms: List[str],
        age: Optional[int] = None,
        gender: Optional[str] = None,
        heart_rate: Optional[float] = None,
        temperature: Optional[float] = None,
        blood_oxygen: Optional[float] = None,
        systolic_bp: Optional[float] = None,
        diastolic_bp: Optional[float] = None,
        pain: Optional[int] = None,
        duration_days: Optional[int] = None,
        risk_factors: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Perform combined disease inference and clinical severity triage.

        Vitals are optional and only MEASURED values are judged. A vital that was not measured is never replaced
        by a "normal" default (the old defaults of HR 80, SpO2 98, BP 120/80 made unmeasured patients look healthy)."""
        norm_symptoms = [s.strip().lower().replace(" ", "_").replace("-", "_") for s in symptoms if s.strip()]

        def lt(v, x):
            return v is not None and v < x

        def ge(v, x):
            return v is not None and v >= x

        def gt(v, x):
            return v is not None and v > x

        # 1. Determine Physiological Vital Severity (measured vitals only)
        is_urgent_vitals = (
            lt(blood_oxygen, 92.0) or
            gt(heart_rate, 120.0) or
            lt(heart_rate, 45.0) or
            ge(systolic_bp, 165.0) or
            ge(diastolic_bp, 105.0) or
            ge(temperature, 39.5)
        )
        is_doctor_vitals = (
            lt(blood_oxygen, 95.0) or
            gt(heart_rate, 100.0) or
            lt(heart_rate, 55.0) or
            ge(systolic_bp, 140.0) or
            ge(diastolic_bp, 90.0) or
            ge(temperature, 38.0)
        )

        has_critical_symptoms = any(
            s in norm_symptoms for s in [
                "chest_pain", "sharp_chest_pain", "difficulty_breathing",
                "loss_of_consciousness", "seizures", "cough_with_blood",
                "sudden_vision_loss", "paralysis"
            ]
        )

        # 2. Match disease profile from clinical knowledge base
        best_disease = "Acute symptom presentation"
        best_score = -1.0
        best_meta = None

        for d_name, meta in CLINICAL_KNOWLEDGE_BASE.items():
            ref_syms = meta["symptoms"]
            matched = sum(1 for s in norm_symptoms if s in ref_syms or any(s in r or r in s for r in ref_syms))
            score = (matched / max(len(ref_syms), 1)) * 100.0
            if score > best_score:
                best_score = score
                best_disease = d_name
                best_meta = meta

        # Fallback if no matching symptoms
        if best_score <= 0 or not best_meta:
            best_disease = "Clinical observation presentation"
            best_meta = {
                "severity": "doctor" if (is_doctor_vitals or norm_symptoms) else "routine",
                "description": "General clinical presentation based on recorded physiological parameters.",
                "precautions": ["Rest quietly in a comfortable setting", "Maintain adequate hydration", "Observe for developing symptoms"],
                "recommendation": "Consult a healthcare provider if symptoms persist or worsen."
            }
        # Honest strength of the match (audit F-02): how many of the condition's listed symptoms were reported.
        # These are rules, not a trained model, so no made-up percentages.
        if best_score <= 0 or best_meta is None or best_disease == "Clinical observation presentation":
            match = "no clear match"
        elif best_score >= 60:
            match = "strong match"
        elif best_score >= 30:
            match = "partial match"
        else:
            match = "weak match"

        # 3. Final Severity Resolution, with the rule that decided it
        if is_urgent_vitals or has_critical_symptoms or best_meta["severity"] == "urgent":
            resolved_severity = "urgent"
            severity_reason = ("a measured reading is in the danger range" if is_urgent_vitals else
                               "a danger-sign symptom was reported" if has_critical_symptoms else
                               "the matched condition is urgent")
        elif is_doctor_vitals or best_meta["severity"] == "doctor":
            resolved_severity = "doctor"
            severity_reason = ("a measured reading is outside the normal range" if is_doctor_vitals else
                               "the matched condition needs a clinician")
        else:
            resolved_severity = "routine"
            severity_reason = "no danger sign or abnormal reading was reported"

        # 4. The rest of the guided assessment (audit F-04). These only RAISE the urgency, never lower it.
        # REVIEW (clinical reviewer): thresholds below.
        rank = {"routine": 0, "doctor": 1, "urgent": 2}

        def raise_to(level, reason):
            nonlocal resolved_severity, severity_reason
            if rank[level] > rank[resolved_severity]:
                resolved_severity, severity_reason = level, reason

        fever = "fever" in norm_symptoms or "high_fever" in norm_symptoms or ge(temperature, 38.0)
        if fever and any(s in norm_symptoms for s in ("stiff_neck", "confusion", "altered_sensorium")):
            raise_to("urgent", "fever with a stiff neck or confusion can be meningitis or severe malaria")
        if pain is not None and pain >= 8:
            raise_to("doctor", f"severe pain ({pain}/10)")
        if duration_days is not None and duration_days >= 14:
            raise_to("doctor", "symptoms for two weeks or more need a clinician's check")
        risks = [r.lower() for r in (risk_factors or [])]
        if risks and (norm_symptoms or pain):
            raise_to("doctor", f"risk factor: {(risk_factors or [''])[0]}")

        return {
            "disease": best_disease,
            "confidence": match,                    # kept field name for the app; now a plain description
            "severity": resolved_severity,
            "severity_confidence": severity_reason,
            "method": "rules-based symptom checker (not a trained model, not a diagnosis)",
            "description": best_meta["description"],
            "precautions": best_meta["precautions"],
            "recommendation": best_meta["recommendation"]
        }


# Global singleton instance
ml_service = MLService()
