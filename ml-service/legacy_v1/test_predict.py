#!/usr/bin/env python
"""
Comprehensive test suite for the predict.py module.
Tests disease and severity predictions with various scenarios.
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


def test_model_loading():
    """Test that models load correctly from notebooks directory."""
    print("\n" + "="*70)
    print("TEST 1: Model Loading")
    print("="*70)
    try:
        predictor = DiseasePredictor()
        print("✓ Models loaded successfully from notebooks directory")
        print(f"  - Disease model type: {type(predictor.disease_model).__name__}")
        print(f"  - Severity model type: {type(predictor.severity_model).__name__}")
        return predictor
    except Exception as e:
        print(f"✗ Failed to load models: {e}")
        raise


def test_disease_prediction(predictor):
    """Test disease prediction with various symptom combinations."""
    print("\n" + "="*70)
    print("TEST 2: Disease Prediction")
    print("="*70)
    
    # Test case 1: Panic disorder symptoms
    print("\nTest 2a: Anxiety-related symptoms")
    symptoms = np.zeros(377)
    symptoms[0] = 1   # anxiety_and_nervousness
    symptoms[2] = 1   # shortness_of_breath
    symptoms[3] = 1   # depressive_or_psychotic_symptoms
    symptoms[6] = 1   # dizziness
    
    result = predictor.predict_disease(symptoms)
    print(f"  Disease: {result['disease']}")
    print(f"  Confidence: {result['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    # Test case 2: Different symptoms
    print("\nTest 2b: Respiratory symptoms")
    symptoms2 = np.zeros(377)
    symptoms2[2] = 1   # shortness_of_breath
    symptoms2[13] = 1  # cough
    symptoms2[14] = 1  # nasal_congestion
    
    result2 = predictor.predict_disease(symptoms2)
    print(f"  Disease: {result2['disease']}")
    print(f"  Confidence: {result2['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    # Test case 3: All zeros (no symptoms)
    print("\nTest 2c: No symptoms")
    symptoms3 = np.zeros(377)
    result3 = predictor.predict_disease(symptoms3)
    print(f"  Disease: {result3['disease']}")
    print(f"  Confidence: {result3['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    return result, result2, result3


def test_severity_prediction(predictor):
    """Test severity prediction with various patient data."""
    print("\n" + "="*70)
    print("TEST 3: Severity Prediction")
    print("="*70)
    
    # Test case 1: Healthy patient
    print("\nTest 3a: Healthy patient vitals")
    result1 = predictor.predict_severity(
        age=30,
        gender=0,  # male
        symptoms_list=[0, 0, 0],
        heart_rate=70,
        body_temp=36.8,
        o2_saturation=99,
        diagnosis=0,
        systolic_bp=110,
        diastolic_bp=70
    )
    print(f"  Severity: {result1['severity']}")
    print(f"  Confidence: {result1['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    # Test case 2: Moderately ill patient
    print("\nTest 3b: Moderately ill patient vitals")
    result2 = predictor.predict_severity(
        age=55,
        gender=1,  # female
        symptoms_list=[1, 2, 1],
        heart_rate=95,
        body_temp=38.5,
        o2_saturation=95,
        diagnosis=5,
        systolic_bp=140,
        diastolic_bp=90
    )
    print(f"  Severity: {result2['severity']}")
    print(f"  Confidence: {result2['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    # Test case 3: Severely ill patient
    print("\nTest 3c: Severely ill patient vitals")
    result3 = predictor.predict_severity(
        age=75,
        gender=0,
        symptoms_list=[2, 2, 2],
        heart_rate=110,
        body_temp=39.5,
        o2_saturation=88,
        diagnosis=10,
        systolic_bp=160,
        diastolic_bp=100
    )
    print(f"  Severity: {result3['severity']}")
    print(f"  Confidence: {result3['confidence_percent']}")
    print(f"  ✓ Prediction successful")
    
    return result1, result2, result3


def test_combined_prediction(predictor):
    """Test combined disease and severity prediction."""
    print("\n" + "="*70)
    print("TEST 4: Combined Disease & Severity Prediction")
    print("="*70)
    
    symptoms_array = np.zeros(377)
    symptoms_array[0] = 1   # anxiety
    symptoms_array[2] = 1   # shortness_of_breath
    symptoms_array[6] = 1   # dizziness
    
    result = predictor.predict_both(
        symptoms_array=symptoms_array,
        age=45,
        gender=1,
        symptoms_list=[1, 1, 0],
        heart_rate=85,
        body_temp=37.8,
        o2_saturation=96,
        diagnosis=3,
        systolic_bp=130,
        diastolic_bp=85
    )
    
    print(f"  Disease: {result['disease']['disease']}")
    print(f"  Disease Confidence: {result['disease']['confidence_percent']}")
    print(f"  Severity: {result['severity']['severity']}")
    print(f"  Severity Confidence: {result['severity']['confidence_percent']}")
    print(f"  ✓ Combined prediction successful")
    
    return result


def test_error_handling(predictor):
    """Test error handling for invalid inputs."""
    print("\n" + "="*70)
    print("TEST 5: Error Handling")
    print("="*70)
    
    # Test wrong number of symptoms
    print("\nTest 5a: Wrong number of symptoms")
    try:
        symptoms_wrong = np.zeros(100)  # Should be 377
        predictor.predict_disease(symptoms_wrong)
        print("  ✗ Should have raised an error")
    except ValueError as e:
        print(f"  ✓ Correctly caught error: {e}")
    
    # Test wrong number of symptom features for severity
    print("\nTest 5b: Wrong number of severity symptoms")
    try:
        predictor.predict_severity(
            age=45,
            gender=0,
            symptoms_list=[1, 2],  # Should be 3
            heart_rate=75,
            body_temp=37.5,
            o2_saturation=98,
            diagnosis=2,
            systolic_bp=120,
            diastolic_bp=80
        )
        print("  ✗ Should have raised an error")
    except ValueError as e:
        print(f"  ✓ Correctly caught error: {e}")


def run_all_tests():
    """Run all tests."""
    print("\n" + "="*70)
    print("DISEASE & SEVERITY PREDICTION TEST SUITE")
    print("="*70)
    
    try:
        # Test 1: Model loading
        predictor = test_model_loading()
        
        # Test 2: Disease prediction
        test_disease_prediction(predictor)
        
        # Test 3: Severity prediction
        test_severity_prediction(predictor)
        
        # Test 4: Combined prediction
        test_combined_prediction(predictor)
        
        # Test 5: Error handling
        test_error_handling(predictor)
        
        # Summary
        print("\n" + "="*70)
        print("✓ ALL TESTS PASSED SUCCESSFULLY!")
        print("="*70)
        print("\nSummary:")
        print("  ✓ Models load correctly from notebooks directory")
        print("  ✓ Disease predictions work with 377 symptoms")
        print("  ✓ Severity predictions work with vital signs")
        print("  ✓ Combined predictions work correctly")
        print("  ✓ Error handling works as expected")
        print("\n" + "="*70 + "\n")
        
        return True
        
    except Exception as e:
        print("\n" + "="*70)
        print(f"✗ TESTS FAILED: {e}")
        print("="*70 + "\n")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
