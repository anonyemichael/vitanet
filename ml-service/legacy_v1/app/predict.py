import pickle
import os
import sys
import numpy as np
import pandas as pd
from pathlib import Path
import json

# Handle Unicode on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Mapping of symptom names to indices (377 symptoms)
SYMPTOM_MAPPING = {
    'anxiety': 0,
    'anxiety_and_nervousness': 0,
    'depression': 1,
    'shortness_of_breath': 2,
    'shortness of breath': 2,
    'sob': 2,
    'depressive_symptoms': 3,
    'sharp_chest_pain': 4,
    'chest_pain': 4,
    'chest pain': 4,
    'chest': 4,
    'dizziness': 6,
    'dizzy': 6,
    'insomnia': 7,
    'chest_tightness': 8,
    'chest tightness': 8,
    'tightness': 8,
    'palpitations': 9,
    'palpitation': 9,
    'irregular_heartbeat': 10,
    'irregular heartbeat': 10,
    'irregular': 10,
    'breathing_fast': 11,
    'fast breathing': 11,
    'shortness': 2,
    'hoarse_voice': 12,
    'hoarse': 12,
    'sore_throat': 13,
    'throat': 13,
    'sore': 13,
    'cough': 15,
    'nasal_congestion': 16,
    'congestion': 16,
    'nasal': 16,
    'fever': 100,
    'fatigue': 150,
    'tired': 150,
    'nausea': 200,
    'headache': 250,
    'head': 250,
}

SEVERITY_LEVELS = {
    0: "mild or low",
    1: "moderate",
    2: "severe or high"
}


class DiseasePredictor:
    """
    Predicts disease and severity using pre-trained models and label encoders
    from the notebooks directory.
    
    Usage:
        predictor = DiseasePredictor()
        
        # Predict disease
        disease_result = predictor.predict_disease(symptoms_array)
        
        # Predict severity
        severity_result = predictor.predict_severity(age=45, gender=0, ...)
    """
    
    def __init__(self, models_dir=None):
        """
        Initialize the predictor by loading models and encoders.
        
        Args:
            models_dir (str): Path to directory containing models and encoders.
                            If None, uses parent directory's notebooks folder.
        """
        if models_dir is None:
            project_root = Path(__file__).parent.parent
            models_dir = project_root / "notebooks"
        
        self.models_dir = Path(models_dir)
        
        try:
            # Load disease model and encoder
            self.disease_model = self._load_pickle("disease_prediction_model.pkl")
            self.disease_encoder = self._load_pickle("disease_label_encoder.pkl")
            
            # Load severity model and encoder
            self.severity_model = self._load_pickle("severity_prediction_model.pkl")
            self.severity_encoder = self._load_pickle("severity_label_encoder.pkl")
            
            print("✓ Models loaded successfully!")
        except Exception as e:
            print(f"✗ Error loading models: {e}")
            raise
        
    def _load_pickle(self, filename):
        """Load a pickle file using joblib (more robust for scikit-learn models)."""
        filepath = self.models_dir / filename
        if not filepath.exists():
            raise FileNotFoundError(f"Model file not found: {filepath}")
        
        try:
            import joblib
            return joblib.load(filepath)
        except ImportError:
            return self._load_with_custom_unpickler(filepath)
        except Exception as e:
            return self._load_with_custom_unpickler(filepath)
    
    def _load_with_custom_unpickler(self, filepath):
        """Load pickle with custom Unpickler to handle STACK_GLOBAL errors."""
        try:
            with open(filepath, "rb") as f:
                unpickler = pickle.Unpickler(f, encoding='latin1')
                return unpickler.load()
        except Exception:
            with open(filepath, "rb") as f:
                unpickler = pickle.Unpickler(f, encoding='utf-8')
                return unpickler.load()
    
    def predict_disease(self, symptoms_array):
        """
        Predict disease from symptoms array.
        
        Args:
            symptoms_array (array-like): Array of symptom features (377 binary values: 0 or 1)
        
        Returns:
            dict: Disease prediction with label and probability
        """
        symptoms_array = np.array(symptoms_array).reshape(1, -1)
        
        if symptoms_array.shape[1] != 377:
            raise ValueError(f"Expected 377 symptoms, got {symptoms_array.shape[1]}")
        
        disease_pred = self.disease_model.predict(symptoms_array)[0]
        disease_proba = np.max(self.disease_model.predict_proba(symptoms_array))
        disease_label = self.disease_encoder.inverse_transform([disease_pred])[0]
        
        return {
            "disease": disease_label,
            "disease_probability": float(disease_proba),
            "confidence_percent": f"{disease_proba*100:.2f}%"
        }
    
    def predict_severity(self, age, gender, symptoms_list, heart_rate, 
                        body_temp, o2_saturation, diagnosis, 
                        systolic_bp, diastolic_bp):
        """
        Predict disease severity from vital signs and patient info.
        
        Args:
            age (int): Patient age
            gender (int): 0 for male, 1 for female
            symptoms_list (list): List of 3 encoded symptom values
            heart_rate (int): Heart rate in bpm
            body_temp (float): Body temperature in Celsius
            o2_saturation (int): Oxygen saturation percentage (0-100)
            diagnosis (int): Encoded diagnosis value
            systolic_bp (int): Systolic blood pressure
            diastolic_bp (int): Diastolic blood pressure
        
        Returns:
            dict: Severity prediction with label and probability
        """
        if len(symptoms_list) != 3:
            raise ValueError(f"Expected 3 symptoms, got {len(symptoms_list)}")
        
        patient_id = 0
        features = np.array([[
            patient_id, age, gender, 
            symptoms_list[0], symptoms_list[1], symptoms_list[2],
            heart_rate, body_temp, o2_saturation, diagnosis,
            systolic_bp, diastolic_bp
        ]])
        
        severity_pred = self.severity_model.predict(features)[0]
        severity_proba = np.max(self.severity_model.predict_proba(features))
        severity_label = self.severity_encoder.inverse_transform([severity_pred])[0]
        
        return {
            "severity": str(severity_label),
            "severity_probability": float(severity_proba),
            "confidence_percent": f"{severity_proba*100:.2f}%"
        }
    
    def predict_both(self, symptoms_array, age, gender, symptoms_list, 
                     heart_rate, body_temp, o2_saturation, diagnosis, 
                     systolic_bp, diastolic_bp):
        """
        Predict both disease and severity in one call.
        
        Args:
            symptoms_array: 377 symptom features for disease prediction
            age, gender, symptoms_list, heart_rate, body_temp, o2_saturation,
            diagnosis, systolic_bp, diastolic_bp: Parameters for severity prediction
        
        Returns:
            dict: Combined predictions for both disease and severity
        """
        disease_result = self.predict_disease(symptoms_array)
        severity_result = self.predict_severity(
            age, gender, symptoms_list, heart_rate, 
            body_temp, o2_saturation, diagnosis, 
            systolic_bp, diastolic_bp
        )
        
        return {
            "disease": disease_result,
            "severity": severity_result
        }


def print_results(results):
    """Pretty print prediction results."""
    if "disease" in results and "severity" in results:
        # Combined results
        print("\n" + "="*60)
        print("DISEASE & SEVERITY PREDICTION RESULTS")
        print("="*60)
        print("\n🏥 DISEASE PREDICTION:")
        print(f"   Disease: {results['disease']['disease']}")
        print(f"   Confidence: {results['disease']['confidence_percent']}")
        print("\n⚠️  SEVERITY PREDICTION:")
        print(f"   Severity Level: {results['severity']['severity']}")
        print(f"   Confidence: {results['severity']['confidence_percent']}")
        print("="*60 + "\n")
    else:
        # Single result
        print("\n" + "-"*60)
        if "disease" in results:
            print("🏥 DISEASE PREDICTION:")
            print(f"   Disease: {results['disease']}")
            print(f"   Confidence: {results['confidence_percent']}")
        else:
            print("⚠️  SEVERITY PREDICTION:")
            print(f"   Severity Level: {results['severity']}")
            print(f"   Confidence: {results['confidence_percent']}")
        print("-"*60 + "\n")


def format_natural_language_output(patient_data, disease_result, severity_result):
    """
    Format predictions as natural language sentences.
    
    Args:
        patient_data: Patient information (age, gender, symptoms)
        disease_result: Disease prediction result
        severity_result: Severity prediction result
    
    Returns:
        str: Natural language report
    """
    disease = disease_result['disease']
    disease_conf = disease_result['disease_probability']
    severity = int(severity_result['severity'])
    severity_conf = severity_result['severity_probability']
    
    gender = "male" if patient_data.get('gender', 0) == 0 else "female"
    age = patient_data.get('age', 'unknown')
    symptoms = patient_data.get('symptoms_text', 'reported symptoms')
    
    severity_text = SEVERITY_LEVELS.get(severity, "moderate")
    
    # Build natural language output
    report = []
    report.append(f"\n{'='*70}")
    report.append("PATIENT HEALTH ASSESSMENT REPORT")
    report.append(f"{'='*70}\n")
    
    report.append(f"Patient Profile:")
    report.append(f"  Age: {age} years old")
    report.append(f"  Gender: {gender}")
    report.append(f"  Chief Complaint: {symptoms}\n")
    
    report.append(f"Clinical Assessment:\n")
    report.append(
        f"Based on the patient's reported {symptoms}, the clinical analysis "
        f"indicates a strong likelihood of {disease}. This diagnosis is supported "
        f"with a confidence level of {disease_result['confidence_percent']}, suggesting "
        f"that there is approximately a {disease_conf*100:.1f}% probability that the patient's "
        f"condition aligns with {disease}.\n"
    )
    
    report.append(f"Severity Assessment:\n")
    report.append(
        f"The patient's vital signs and clinical parameters indicate a "
        f"{severity_text} level of disease severity. This assessment carries a confidence "
        f"of {severity_result['confidence_percent']}, meaning there is approximately "
        f"a {severity_conf*100:.1f}% probability that the condition is classified as {severity_text}.\n"
    )
    
    # Clinical recommendations based on severity
    if severity == 0:
        report.append(
            f"Recommendations:\n"
            f"  - The patient appears to be in mild condition and may benefit from "
            f"outpatient management.\n"
            f"  - Home care and over-the-counter symptom management may be appropriate.\n"
            f"  - Follow-up consultation recommended if symptoms persist or worsen.\n"
        )
    elif severity == 1:
        report.append(
            f"Recommendations:\n"
            f"  - The patient requires standard medical care and monitoring.\n"
            f"  - Office-based evaluation and treatment are recommended.\n"
            f"  - Regular follow-up appointments should be scheduled.\n"
            f"  - Further diagnostic testing may be necessary.\n"
        )
    else:
        report.append(
            f"Recommendations:\n"
            f"  - The patient requires urgent medical attention.\n"
            f"  - Immediate hospitalization or emergency care may be necessary.\n"
            f"  - Comprehensive diagnostic workup should be initiated.\n"
            f"  - Close monitoring and intensive treatment are recommended.\n"
        )
    
    report.append(f"\n{'='*70}\n")
    
    return "\n".join(report)


def get_user_input_interactive():
    """
    Interactively collect patient information from the user.
    
    Returns:
        dict: Patient data including symptoms, age, gender, and vitals
    """
    print("\n" + "="*70)
    print("INTERACTIVE PATIENT DATA COLLECTION")
    print("="*70 + "\n")
    
    # Collect basic patient information
    while True:
        try:
            age = int(input("Enter patient age (years): "))
            if age < 0 or age > 150:
                print("Please enter a valid age (0-150)")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    print("\nSelect patient gender:")
    print("  0 = Male")
    print("  1 = Female")
    while True:
        try:
            gender = int(input("Enter gender (0 or 1): "))
            if gender not in [0, 1]:
                print("Please enter 0 or 1")
                continue
            break
        except ValueError:
            print("Please enter 0 or 1")
    
    # Collect symptoms
    print("\n" + "-"*70)
    print("SYMPTOM COLLECTION")
    print("-"*70)
    print("\nEnter symptoms (type 'done' when finished).")
    print("Common symptoms: anxiety, depression, chest pain, shortness of breath,")
    print("                 dizziness, cough, fever, nausea, headache, fatigue\n")
    
    symptoms_array = np.zeros(377)
    symptoms_entered = []
    
    while True:
        symptom_input = input("Enter a symptom (or 'done'): ").lower().strip()
        
        if symptom_input == 'done':
            if len(symptoms_entered) == 0:
                print("Please enter at least one symptom")
                continue
            break
        
        if symptom_input == '':
            continue
        
        # Find symptom in mapping
        symptom_idx = SYMPTOM_MAPPING.get(symptom_input)
        if symptom_idx is not None:
            symptoms_array[symptom_idx] = 1
            symptoms_entered.append(symptom_input)
            print(f"  ✓ Added: {symptom_input}")
        else:
            print(f"  ✗ Symptom '{symptom_input}' not recognized. Try another.")
    
    # Collect vital signs
    print("\n" + "-"*70)
    print("VITAL SIGNS COLLECTION")
    print("-"*70 + "\n")
    
    while True:
        try:
            heart_rate = int(input("Enter heart rate (bpm, typical: 60-100): "))
            if heart_rate < 0 or heart_rate > 300:
                print("Please enter a valid heart rate")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    while True:
        try:
            body_temp = float(input("Enter body temperature (°C, typical: 36.5-37.5): "))
            if body_temp < 35 or body_temp > 45:
                print("Please enter a valid temperature")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    while True:
        try:
            o2_sat = int(input("Enter O2 saturation (%, typical: 95-100): "))
            if o2_sat < 0 or o2_sat > 100:
                print("Please enter a value between 0-100")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    while True:
        try:
            sys_bp = int(input("Enter systolic blood pressure (mmHg, typical: 110-120): "))
            if sys_bp < 0 or sys_bp > 300:
                print("Please enter a valid systolic BP")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    while True:
        try:
            dia_bp = int(input("Enter diastolic blood pressure (mmHg, typical: 70-80): "))
            if dia_bp < 0 or dia_bp > 150:
                print("Please enter a valid diastolic BP")
                continue
            break
        except ValueError:
            print("Please enter a valid number")
    
    # Default values for severity model (3 symptom codes)
    symptoms_list = [1, 1, 0]  # Default severity symptom codes
    diagnosis = 2  # Default diagnosis code
    
    patient_data = {
        'age': age,
        'gender': gender,
        'symptoms_array': symptoms_array,
        'symptoms_text': ", ".join(symptoms_entered),
        'symptoms_list': symptoms_list,
        'heart_rate': heart_rate,
        'body_temp': body_temp,
        'o2_saturation': o2_sat,
        'diagnosis': diagnosis,
        'systolic_bp': sys_bp,
        'diastolic_bp': dia_bp,
    }
    
    return patient_data


if __name__ == "__main__":
    try:
        print("\n" + "="*70)
        print("DISEASE & SEVERITY PREDICTION SYSTEM")
        print("="*70)
        print("\nInitializing Disease & Severity Predictor...\n")
        
        predictor = DiseasePredictor()
        
        # Get user input interactively
        patient_data = get_user_input_interactive()
        
        print("\n" + "-"*70)
        print("PROCESSING PREDICTIONS...")
        print("-"*70 + "\n")
        
        # Make combined prediction
        combined_result = predictor.predict_both(
            symptoms_array=patient_data['symptoms_array'],
            age=patient_data['age'],
            gender=patient_data['gender'],
            symptoms_list=patient_data['symptoms_list'],
            heart_rate=patient_data['heart_rate'],
            body_temp=patient_data['body_temp'],
            o2_saturation=patient_data['o2_saturation'],
            diagnosis=patient_data['diagnosis'],
            systolic_bp=patient_data['systolic_bp'],
            diastolic_bp=patient_data['diastolic_bp']
        )
        
        # Display natural language output
        natural_language_report = format_natural_language_output(
            patient_data,
            combined_result['disease'],
            combined_result['severity']
        )
        print(natural_language_report)
        
        print("✓ Prediction completed successfully!")
        
    except KeyboardInterrupt:
        print("\n\n✗ Process interrupted by user.")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()

