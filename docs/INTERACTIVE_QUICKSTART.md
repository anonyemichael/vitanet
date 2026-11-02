QUICK START GUIDE - INTERACTIVE PREDICTION
======================================================================

WHAT'S NEW:
===========

The predict.py file now supports INTERACTIVE mode where users can:
  ✓ Enter symptoms in natural language
  ✓ Input vital signs
  ✓ Get BOTH disease and severity predictions at once
  ✓ Receive results as professional clinical report with natural language


HOW TO USE:
===========

1. OPEN COMMAND PROMPT
   cd C:\Users\steph\PycharmProjects\JupyterProject

2. RUN THE PREDICTOR
   python app/predict.py

3. FOLLOW PROMPTS
   - Enter patient age (example: 45)
   - Enter patient gender (0 for male, 1 for female)
   - Enter symptoms (type 'done' when finished)
   - Enter vital signs when prompted

4. VIEW RESULTS
   - Professional clinical assessment report
   - Disease diagnosis with confidence
   - Severity level with recommendations


EXAMPLE SESSION:
================

$ python app/predict.py

[System prompts appear...]
Enter patient age (years): 55
Select patient gender:
  0 = Male
  1 = Female
Enter gender (0 or 1): 1

SYMPTOM COLLECTION
Enter symptoms (type 'done' when finished).
Common symptoms: anxiety, depression, chest pain, shortness of breath,
                 dizziness, cough, fever, nausea, headache, fatigue

Enter a symptom (or 'done'): chest pain
  ✓ Added: chest pain
Enter a symptom (or 'done'): dizziness
  ✓ Added: dizziness
Enter a symptom (or 'done'): fatigue
  ✓ Added: fatigue
Enter a symptom (or 'done'): done

VITAL SIGNS COLLECTION
Enter heart rate (bpm, typical: 60-100): 88
Enter body temperature (°C, typical: 36.5-37.5): 37.2
Enter O2 saturation (%, typical: 95-100): 97
Enter systolic blood pressure (mmHg, typical: 110-120): 140
Enter diastolic blood pressure (mmHg, typical: 70-80): 90

[Results display...]

======================================================================
PATIENT HEALTH ASSESSMENT REPORT
======================================================================

Patient Profile:
  Age: 55 years old
  Gender: female
  Chief Complaint: chest pain, dizziness, fatigue

Clinical Assessment:

Based on the patient's reported chest pain, dizziness, fatigue, the
clinical analysis indicates a strong likelihood of [DISEASE]. This
diagnosis is supported with a confidence level of XX.XX%, suggesting
that there is approximately a XX% probability that the patient's
condition aligns with [DISEASE].

Severity Assessment:

The patient's vital signs and clinical parameters indicate a [moderate/
severe] level of disease severity. This assessment carries a confidence
of XX.XX%, meaning there is approximately a XX% probability that the
condition is classified as [moderate/severe].

Recommendations:
  - [Recommendation 1]
  - [Recommendation 2]
  - [Recommendation 3]
  - [Recommendation 4]

======================================================================


AVAILABLE SYMPTOMS:
===================

Simple to enter - just type the symptom name:

Common symptoms you can type:
  anxiety, depression, chest pain, shortness of breath,
  dizziness, cough, fever, nausea, headache, fatigue,
  chest tightness, palpitations, irregular heartbeat,
  throat pain, sore throat, insomnia, hoarse voice, etc.

The system is flexible - try natural language:
  - "chest pain" or "chest" or "chest_pain" - all work!
  - "shortness of breath" or "sob" or "shortness" - all work!
  - "dizziness" or "dizzy" - both work!
  - "fatigue" or "tired" - both work!


VITAL SIGNS GUIDELINES:
======================

Heart Rate:
  Typical: 60-100 bpm
  Low: < 60 (bradycardia)
  High: > 100 (tachycardia)

Body Temperature:
  Normal: 36.5-37.5°C
  Fever: > 38°C
  Hypothermia: < 36°C

Oxygen Saturation:
  Normal: 95-100%
  Low: < 90%

Blood Pressure:
  Normal: 110-120 systolic, 70-80 diastolic
  High: > 130 systolic, > 85 diastolic
  Low: < 90 systolic, < 60 diastolic


OUTPUT FORMAT:
==============

The system provides a PROFESSIONAL CLINICAL REPORT that includes:

1. Patient Profile
   - Age, gender, symptoms

2. Clinical Assessment
   - Disease diagnosis
   - Confidence level as percentage
   - Probability explanation

3. Severity Assessment
   - Severity level (mild/moderate/severe)
   - Confidence level
   - What it means

4. Recommendations
   - Mild case: Home care, follow-up
   - Moderate case: Office care, monitoring
   - Severe case: Urgent care, hospitalization


KEY FEATURES:
=============

✓ Interactive input collection
✓ Real-time validation
✓ Natural language symptom input (40+ variations)
✓ Combined disease + severity prediction
✓ Professional report format
✓ Natural language explanations
✓ Severity-based recommendations
✓ User-friendly interface


TROUBLESHOOTING:
================

"Symptom not recognized"
  → Try a simpler name or similar phrase
  → Common variations usually work
  → Example: try "chest" instead of "chest_pain"

Invalid age/number
  → Make sure you enter only numbers
  → Use realistic values (age 0-150, HR 0-300, etc.)

Stuck on input
  → Type 'done' to finish symptom entry
  → Or Ctrl+C to exit the program


MORE INFORMATION:
=================

For detailed API documentation:
  See: PREDICT_GUIDE.md

For usage examples:
  See: examples.py

For test suite:
  Run: python test_predict.py

For interactive examples:
  Run: python examples.py

======================================================================
