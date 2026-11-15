# VitaNet ML Service — Legacy v1 (Deprecated Prototype)

> [!WARNING]
> This directory contains the **archived Legacy v1 ML prototype** (XGBoost 377-symptom classifier and vital sign severity predictor).
> It is preserved for reference, historical benchmarks, and backward compatibility only.
> **DO NOT** use this code for the new model. The active model development is in [`ml-service/new_model/`](../new_model/).

---

## Architecture Overview

The v1 model was an initial machine learning prototype designed for:
1. **Disease Classification**: XGBoost model mapping a 377-element binary symptom array to disease diagnoses.
2. **Severity Assessment**: Small tabular XGBoost classifier mapping 12 physiological variables (age, sex, vitals, primary symptoms) to a severity category (0: mild, 1: moderate, 2: severe).

## Contents

- [`notebooks/`](./notebooks/):
  - `disease_model.ipynb`: Training notebook for 377-symptom XGBoost classifier.
  - `severinity_model.ipynb`: Training notebook for tabular severity predictor.
  - `disease_prediction_model.pkl`: Serialized XGBoost model weights (10 MB).
  - `disease_label_encoder.pkl`: Label encoder for disease classes.
  - `severity_prediction_model.pkl`: Serialized severity model weights.
  - `severity_label_encoder.pkl`: Label encoder for severity classes.
- [`app/`](./app/):
  - `predict.py`: `DiseasePredictor` class providing CLI inference and model loading.
  - `main.py`: Prototype FastAPI server serving `/predict/disease` and `/predict/severity`.
- [`examples.py`](./examples.py): Example patient cases for the legacy predictor.
- [`test_predict.py`](./test_predict.py): Unit test suite for `DiseasePredictor`.
- [`sample.ipynb`](./sample.ipynb): Ad-hoc interactive test notebook.

## How to Run (Historical Reference)

```bash
cd ml-service/legacy_v1
python -m unittest test_predict.py
```
