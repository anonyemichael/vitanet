# VitaNet Machine Learning & AI Services

This directory manages the machine learning integration and AI services for the VitaNet app and hospital portal.

---

## 🌟 Active Model Development

The new clinical model is actively developed in its dedicated repository:
👉 **[`C:\Users\CARLVYN\Desktop\Vitanet AI Model\vitanet-model`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model)**

- **Target**: Conversational medical diagnostic reasoning model fine-tuned for Ghana (English and Twi).
- **Master Project Spec**: [`docs/project_spec.md`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model/docs/project_spec.md)
- **Portal Tasks Spec**: [`docs/portal-ai-model-spec.md`](../docs/portal-ai-model-spec.md) / [`portal_tasks_spec.md`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model/docs/portal_tasks_spec.md)
- **Integration Workspace**: [`ml-service/new_model/`](./new_model/) (holds imported checkpoints and serving wrappers for VitaNet backend)

---

## 📁 Directory Structure

```
ml-service/
├── new_model/              # 🌟 Integration point for the new model on Desktop
│   ├── checkpoints/        # Exported production weights & LoRA adapters
│   ├── inference/          # Serving API & backend integration wrappers
│   ├── datasets/           # Local benchmark & test splits
│   └── README.md           # Model architecture, specifications & instructions
│
├── legacy_v1/              # 📦 ARCHIVED V1 PROTOTYPE (Deprecated)
│   ├── app/                # Old predict.py & main.py
│   ├── notebooks/          # Old disease_model.ipynb, severinity_model.ipynb
│   │   ├── disease_prediction_model.pkl (v1 XGBoost 377 symptom model)
│   │   └── severity_prediction_model.pkl (v1 severity model)
│   ├── test_predict.py     # Legacy test suite
│   ├── examples.py         # Legacy usage examples
│   └── README.md           # Documentation for the deprecated v1 prototype
│
├── data/                   # 📊 REFERENCE CLINICAL DATASETS
│   ├── disease_diagnosis.csv         # Clinical dataset (used by backend triage fallback)
│   ├── final_symptoms_to_disease.csv # Reference 377-symptom matrix
│   ├── openapi.json                  # Legacy API spec
│   └── README.md                     # Dataset documentation
│
├── app/                    # Non-breaking backward-compatibility stubs pointing to legacy_v1
└── requirements.txt        # Python dependencies
```

---

## 📦 Legacy Model (v1)

- The legacy XGBoost 377-symptom classifier and severity model have been archived into [`ml-service/legacy_v1/`](./legacy_v1/).
- Preserved solely for historical reference and backward compatibility.
