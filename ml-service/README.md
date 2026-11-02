# VitaNet ML Service

Disease prediction and severity assessment microservice using pre-trained XGBoost models.

## Models

| Model | Input | Output | File |
|-------|-------|--------|------|
| Disease Prediction | 377 binary symptom features | Disease label + probability | `notebooks/disease_prediction_model.pkl` |
| Severity Prediction | 12 patient features (age, gender, vitals) | Severity level (0–2) + probability | `notebooks/severity_prediction_model.pkl` |

## Quick Start

```bash
cd ml-service
pip install -r requirements.txt

# Interactive CLI
python app/predict.py

# REST API
uvicorn app.main:app --reload

# Run tests
python test_predict.py

# Run examples
python examples.py
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check |
| `POST` | `/predict` | Predict both disease and severity |
| `POST` | `/predict/disease` | Predict disease from 377-element symptom array |
| `POST` | `/predict/severity` | Predict severity from vital signs |

## Directory Structure

```
ml-service/
├── app/
│   ├── main.py          # FastAPI application
│   ├── predict.py        # DiseasePredictor class + CLI
│   ├── Dockerfile
│   └── profile
├── data/
│   ├── disease_diagnosis.csv
│   ├── final_symptoms_to_disease.csv
│   ├── models.json
│   ├── models_utf8.json
│   └── openapi.json
├── notebooks/
│   ├── disease_model.ipynb
│   ├── severinity_model.ipynb
│   ├── disease_prediction_model.pkl
│   ├── disease_label_encoder.pkl
│   ├── severity_prediction_model.pkl
│   └── severity_label_encoder.pkl
├── test_predict.py       # Test suite
├── examples.py           # Usage examples
├── requirements.txt      # Python dependencies
└── sample.ipynb
```
