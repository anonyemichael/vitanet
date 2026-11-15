# VitaNet Reference Datasets

| File | Size | Description | Used By |
|------|------|-------------|---------|
| `disease_diagnosis.csv` | 193 KB | Clinical dataset of diseases, symptom correlations, and triage severities. | Backend clinical knowledge base (`vitanet-backend/app/services/ml_service.py`) and legacy training notebook. |
| `final_symptoms_to_disease.csv` | 22 MB | Large symptom-to-disease matrix across 377 symptom features. | Legacy v1 disease model notebook (`legacy_v1/notebooks/disease_model.ipynb`). |
| `openapi.json` | 5.8 KB | Exported OpenAPI specification of the v1 prediction endpoints. | Reference only. |
