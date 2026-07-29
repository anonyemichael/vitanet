# Disease and Severity Prediction Guide

## Overview

The `predict.py` module provides a `DiseasePredictor` class that uses pre-trained machine learning models to predict diseases and their severity levels based on patient symptoms, vital signs, and health metrics.

## Features

- **Disease Prediction**: Predicts the most likely disease from 377 symptom features
- **Severity Prediction**: Predicts disease severity level from vital signs and patient data
- **Combined Prediction**: Predicts both disease and severity in a single call
- **Confidence Scores**: Provides probability estimates for predictions
- **Error Handling**: Validates input data and provides helpful error messages

## Prerequisites

All required packages are listed in `requirements.txt`:
```
pandas~=3.0.5
numpy~=2.5.1
matplotlib~=3.11.1
seaborn~=0.13.2
joblib~=1.5.3
scikit-learn~=1.9.0
xgboost~=3.3.0
```

Install with:
```bash
pip install -r requirements.txt
```

## Models

The module uses two pre-trained XGBoost models located in the `notebooks/` directory:

1. **Disease Prediction Model** (`disease_prediction_model.pkl`)
   - Input: 377 binary symptom features (0 or 1)
   - Output: Disease classification with probability
   - Encoder: `disease_label_encoder.pkl`

2. **Severity Prediction Model** (`severity_prediction_model.pkl`)
   - Input: 12 patient features (age, gender, symptoms, vitals, etc.)
   - Output: Severity level classification with probability
   - Encoder: `severity_label_encoder.pkl`

## Usage

### Basic Setup

```python
from app.predict import DiseasePredictor
import numpy as np

# Initialize the predictor
predictor = DiseasePredictor()
```

### Disease Prediction

Predict disease from 377 symptom features:

```python
# Create symptom array (377 binary values: 0 or 1)
symptoms = np.zeros(377)
symptoms[0] = 1   # Set specific symptoms to 1
symptoms[2] = 1
symptoms[5] = 1

# Make prediction
result = predictor.predict_disease(symptoms)
print(result)
# Output: {
#     'disease': 'panic disorder',
#     'disease_probability': 0.3264,
#     'confidence_percent': '32.64%'
# }
```

### Severity Prediction

Predict severity from vital signs and patient data:

```python
result = predictor.predict_severity(
    age=45,                    # Patient age (years)
    gender=0,                  # 0=male, 1=female
    symptoms_list=[0, 1, 2],   # 3 encoded symptom values
    heart_rate=75,             # Heart rate (bpm)
    body_temp=37.5,            # Body temperature (°C)
    o2_saturation=98,          # Oxygen saturation (0-100%)
    diagnosis=2,               # Encoded diagnosis value
    systolic_bp=120,           # Systolic blood pressure (mmHg)
    diastolic_bp=80            # Diastolic blood pressure (mmHg)
)
print(result)
# Output: {
#     'severity': '1',
#     'severity_probability': 0.8236,
#     'confidence_percent': '82.36%'
# }
```

### Combined Prediction

Predict both disease and severity in one call:

```python
symptoms = np.zeros(377)
symptoms[0] = 1
symptoms[2] = 1

result = predictor.predict_both(
    symptoms_array=symptoms,
    age=45,
    gender=0,
    symptoms_list=[0, 1, 2],
    heart_rate=75,
    body_temp=37.5,
    o2_saturation=98,
    diagnosis=2,
    systolic_bp=120,
    diastolic_bp=80
)
print(result)
# Output: {
#     'disease': {'disease': 'anxiety', 'disease_probability': 0.27, ...},
#     'severity': {'severity': '0', 'severity_probability': 0.9999, ...}
# }
```

## Symptom Features

The disease prediction model uses 377 binary symptom features including:

- Anxiety and nervousness
- Depression
- Shortness of breath
- Chest pain
- Dizziness
- Insomnia
- Cough
- Nasal congestion
- Throat swelling
- Fever
- And many more...

**Note**: Features should be binary (0 or 1) where 1 indicates the symptom is present.

## Severity Input Features

The severity prediction model uses the following 12 features:

| Feature | Type | Range/Notes |
|---------|------|------------|
| patient_id | int | Usually 0 |
| age | int | Years |
| gender | int | 0=male, 1=female |
| symptom_1 | int | Encoded value |
| symptom_2 | int | Encoded value |
| symptom_3 | int | Encoded value |
| heart_rate | int | bpm |
| body_temp | float | Celsius |
| o2_saturation | int | 0-100% |
| diagnosis | int | Encoded diagnosis |
| systolic_bp | int | mmHg |
| diastolic_bp | int | mmHg |

## Output Format

All prediction methods return dictionaries with:

```python
{
    'disease': str,                    # Predicted disease name
    'disease_probability': float,      # Probability (0-1)
    'confidence_percent': str          # Formatted percentage
}
```

or for severity:

```python
{
    'severity': str,                   # Severity level
    'severity_probability': float,     # Probability (0-1)
    'confidence_percent': str          # Formatted percentage
}
```

## Error Handling

The module validates input dimensions and raises helpful errors:

```python
# Wrong number of symptoms
try:
    predictor.predict_disease(np.zeros(100))  # Should be 377
except ValueError as e:
    print(f"Error: {e}")
    # Output: Expected 377 symptoms, got 100

# Wrong number of severity symptoms
try:
    predictor.predict_severity(
        age=45, gender=0,
        symptoms_list=[1, 2],  # Should be 3
        # ... other params
    )
except ValueError as e:
    print(f"Error: {e}")
    # Output: Expected 3 symptoms, got 2
```

## Running Tests

A comprehensive test suite is included:

```bash
python test_predict.py
```

Tests verify:
- Model loading from notebooks directory
- Disease predictions with various symptom combinations
- Severity predictions with different patient vitals
- Combined predictions
- Error handling for invalid inputs

## Running Examples

Run example predictions:

```bash
python app/predict.py
```

This executes three example scenarios:
1. Disease prediction with sample symptoms
2. Severity prediction with sample vital signs
3. Combined prediction with full patient data

## Integration

To use in your own code:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent / "app"))
from predict import DiseasePredictor

predictor = DiseasePredictor()
# Use predictor.predict_disease(), predict_severity(), or predict_both()
```

## Model Information

- **Model Type**: XGBoost Classifier
- **Framework**: scikit-learn compatible
- **Data Format**: NumPy arrays
- **Serialization**: joblib

## Limitations

- Predictions are probabilistic estimates based on training data
- Model performance depends on input data quality
- 377 symptoms must be provided for disease prediction (binary values)
- Severity predictions require specific vital sign inputs
- Not intended for real clinical diagnosis without professional review

## File Structure

```
JupyterProject/
├── app/
│   └── predict.py                    # Main prediction module
├── notebooks/
│   ├── disease_prediction_model.pkl  # Disease model
│   ├── disease_label_encoder.pkl     # Disease encoder
│   ├── severity_prediction_model.pkl # Severity model
│   └── severity_label_encoder.pkl    # Severity encoder
├── models/
│   ├── disease_model.pkl             # Metadata only
│   └── severinity_model.pkl          # Metadata only
├── test_predict.py                   # Test suite
├── PREDICT_GUIDE.md                  # This file
└── requirements.txt                  # Dependencies
```

## Support

For issues or questions:
1. Check that all symptoms/vitals are in correct format
2. Verify models exist in `notebooks/` directory
3. Ensure all dependencies are installed (`pip install -r requirements.txt`)
4. Run `test_predict.py` to verify functionality
