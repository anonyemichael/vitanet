#!/usr/bin/env python
"""
Real-world example of using the DiseasePredictor for patient screening.
This script demonstrates practical usage patterns.
"""

import sys
import os
from pathlib import Path

# Add app directory to path - use absolute path for reliability
project_root = Path(__file__).parent.absolute()
app_dir = project_root / "app"
if str(app_dir) not in sys.path:
    sys.path.insert(0, str(app_dir))

import numpy as np
from predict import DiseasePredictor, print_results


def patient_screening_example():
    """Example: Screening a patient with chest pain and anxiety."""
    
    print("\n" + "="*70)
    print("EXAMPLE: Patient Screening - Chest Pain Case")
    print("="*70)
    
    predictor = DiseasePredictor()
    
    # Patient Information
    patient_data = {
        "name": "John Doe",
        "age": 45,
        "gender": "Male",  # 0 for male
        "chief_complaint": "Chest pain with anxiety"
    }
    
    print(f"\nPatient: {patient_data['name']}")
    print(f"Age: {patient_data['age']}")
    print(f"Chief Complaint: {patient_data['chief_complaint']}")
    
    # Reported Symptoms (377 features)
    # Creating a symptom array based on reported symptoms
    symptoms = np.zeros(377)
    
    # Map reported symptoms to feature indices
    # (In practice, you'd have a mapping of symptom names to indices)
    symptom_mapping = {
        "anxiety_and_nervousness": 0,
        "shortness_of_breath": 2,
        "chest_tightness": 8,
        "palpitations": 9,
        "dizziness": 6,
        "irregular_heartbeat": 10,
    }
    
    reported_symptoms = [
        "anxiety_and_nervousness",
        "shortness_of_breath",
        "chest_tightness",
        "palpitations",
        "dizziness"
    ]
    
    print(f"\nReported Symptoms:")
    for symptom in reported_symptoms:
        if symptom in symptom_mapping:
            idx = symptom_mapping[symptom]
            symptoms[idx] = 1
            print(f"  ✓ {symptom.replace('_', ' ').title()}")
    
    # Vital Signs
    vitals = {
        "heart_rate": 88,        # bpm
        "body_temp": 37.2,       # °C
        "o2_saturation": 97,     # %
        "systolic_bp": 135,      # mmHg
        "diastolic_bp": 85       # mmHg
    }
    
    print(f"\nVital Signs:")
    print(f"  Heart Rate: {vitals['heart_rate']} bpm")
    print(f"  Body Temperature: {vitals['body_temp']}°C")
    print(f"  O2 Saturation: {vitals['o2_saturation']}%")
    print(f"  Blood Pressure: {vitals['systolic_bp']}/{vitals['diastolic_bp']} mmHg")
    
    # Make predictions
    print("\n" + "-"*70)
    print("PREDICTIONS:")
    print("-"*70)
    
    # Disease prediction
    disease_result = predictor.predict_disease(symptoms)
    print(f"\n🏥 Likely Disease: {disease_result['disease']}")
    print(f"   Confidence: {disease_result['confidence_percent']}")
    
    # Severity prediction
    severity_result = predictor.predict_severity(
        age=patient_data['age'],
        gender=0,  # 0 for male
        symptoms_list=[1, 1, 0],  # Example symptom codes
        heart_rate=vitals['heart_rate'],
        body_temp=vitals['body_temp'],
        o2_saturation=vitals['o2_saturation'],
        diagnosis=2,  # Example diagnosis code
        systolic_bp=vitals['systolic_bp'],
        diastolic_bp=vitals['diastolic_bp']
    )
    
    print(f"\n⚠️  Severity Level: {severity_result['severity']}")
    print(f"   Confidence: {severity_result['confidence_percent']}")
    
    # Clinical recommendation
    severity_level = int(severity_result['severity'])
    recommendations = {
        0: "Urgent care - Patient needs immediate evaluation",
        1: "Standard care - Patient should be examined soon",
        2: "Routine care - Outpatient follow-up recommended"
    }
    
    print(f"\n📋 Recommendation: {recommendations.get(severity_level, 'See physician')}")
    
    print("\n" + "="*70 + "\n")


def batch_screening_example():
    """Example: Batch screening multiple patients."""
    
    print("\n" + "="*70)
    print("EXAMPLE: Batch Patient Screening")
    print("="*70)
    
    predictor = DiseasePredictor()
    
    # Simulated patient data
    patients = [
        {"name": "Patient A", "age": 35, "gender": 1, "symptoms": [0, 1, 1]},
        {"name": "Patient B", "age": 52, "gender": 0, "symptoms": [1, 0, 1]},
        {"name": "Patient C", "age": 68, "gender": 1, "symptoms": [1, 1, 0]},
    ]
    
    print(f"\nScreening {len(patients)} patients...\n")
    
    results = []
    for patient in patients:
        severity = predictor.predict_severity(
            age=patient['age'],
            gender=patient['gender'],
            symptoms_list=patient['symptoms'],
            heart_rate=72,
            body_temp=36.8,
            o2_saturation=98,
            diagnosis=1,
            systolic_bp=120,
            diastolic_bp=80
        )
        
        results.append({
            "name": patient['name'],
            "age": patient['age'],
            "severity": severity['severity'],
            "confidence": severity['confidence_percent']
        })
        
        print(f"{patient['name']:12} - Severity: {severity['severity']} "
              f"(Confidence: {severity['confidence_percent']})")
    
    print("\n" + "="*70 + "\n")
    
    return results


def symptom_analysis_example():
    """Example: Analyze impact of different symptom combinations."""
    
    print("\n" + "="*70)
    print("EXAMPLE: Symptom Combination Analysis")
    print("="*70)
    
    predictor = DiseasePredictor()
    
    symptom_combinations = [
        ("No symptoms", []),
        ("Mild anxiety", [0]),
        ("Anxiety + shortness of breath", [0, 2]),
        ("Anxiety + SOB + chest pain", [0, 2, 8]),
        ("All above + dizziness", [0, 2, 8, 6]),
    ]
    
    print("\nAnalyzing different symptom presentations:\n")
    
    for desc, symptom_indices in symptom_combinations:
        symptoms = np.zeros(377)
        for idx in symptom_indices:
            symptoms[idx] = 1
        
        result = predictor.predict_disease(symptoms)
        print(f"{desc:35} → {result['disease']:30} "
              f"({result['confidence_percent']})")
    
    print("\n" + "="*70 + "\n")


def vital_signs_impact_example():
    """Example: Analyze impact of vital signs on severity assessment."""
    
    print("\n" + "="*70)
    print("EXAMPLE: Impact of Vital Signs on Severity")
    print("="*70)
    
    predictor = DiseasePredictor()
    
    vital_profiles = [
        ("Normal vitals", {"hr": 70, "temp": 36.8, "o2": 99, "sbp": 120, "dbp": 80}),
        ("Elevated HR/BP", {"hr": 95, "temp": 37.5, "o2": 97, "sbp": 140, "dbp": 90}),
        ("Concerning vitals", {"hr": 110, "temp": 38.5, "o2": 92, "sbp": 155, "dbp": 100}),
        ("Critical vitals", {"hr": 125, "temp": 39.2, "o2": 85, "sbp": 170, "dbp": 110}),
    ]
    
    print("\nAssessing same patient with different vital signs:\n")
    
    for desc, vitals in vital_profiles:
        result = predictor.predict_severity(
            age=45,
            gender=0,
            symptoms_list=[1, 1, 1],
            heart_rate=vitals['hr'],
            body_temp=vitals['temp'],
            o2_saturation=vitals['o2'],
            diagnosis=2,
            systolic_bp=vitals['sbp'],
            diastolic_bp=vitals['dbp']
        )
        
        print(f"{desc:20} - Severity: {result['severity']} "
              f"({result['confidence_percent']})")
    
    print("\n" + "="*70 + "\n")


if __name__ == "__main__":
    print("\n" + "="*70)
    print("DISEASE PREDICTOR - PRACTICAL EXAMPLES")
    print("="*70)
    
    try:
        # Run examples
        patient_screening_example()
        batch_screening_example()
        symptom_analysis_example()
        vital_signs_impact_example()
        
        print("\n" + "="*70)
        print("✓ All examples completed successfully!")
        print("="*70 + "\n")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
