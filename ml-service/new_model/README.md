# VitaNet AI Model — Active Integration Workspace

> [!IMPORTANT]
> The active model training and development repository is located on your local machine at:  
> **`C:\Users\CARLVYN\Desktop\Vitanet AI Model\vitanet-model`**

---

## 🎯 About the New Model

- **Repository**: [`C:/Users/CARLVYN/Desktop/Vitanet AI Model/vitanet-model`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model)
- **Objective**: Conversational medical diagnostic reasoning model fine-tuned for the Ghanaian clinical context (English and Twi).
- **Core Clinical & Portal Tasks**:
  1. `prep_brief`: Pre-arrival summary for nurses before emergency intake.
  2. `triage_check`: Clinical triage level validation and red flag detection for walk-in arrivals.
  3. `discharge_plan`: Plain-language (12-year-old reading level) post-discharge instructions.
  4. `handover_note`: Standard SBAR clinical shift handover note.
  5. `copilot_prompt`: Bedside clinical copilot decision checklists.

---

## 📁 Repository Integration Map

| VitaNet App / Backend | Model Repository |
|-----------------------|------------------|
| Specifications: [`docs/portal-ai-model-spec.md`](../../docs/portal-ai-model-spec.md) | Spec: [`docs/portal_tasks_spec.md`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model/docs/portal_tasks_spec.md) |
| Training Dataset: [`docs/portal-ai-training-examples.jsonl`](../../docs/portal-ai-training-examples.jsonl) | Data config: [`configs/datasets.yaml`](file:///C:/Users/CARLVYN/Desktop/Vitanet%20AI%20Model/vitanet-model/configs/datasets.yaml) |
| Backend Triage: [`vitanet-backend/app/routes/triage.py`](../../vitanet-backend/app/routes/triage.py) | Serving endpoint / export checkpoint |

---

## 🚀 Deployment & Serving Integration

When checkpoints (GGUF, LoRA adapter, or ONNX) are exported from `vitanet-model`:
- Store exported production weights or adapter weights in `ml-service/new_model/checkpoints/`.
- Inference endpoints and serving wrappers belong in `ml-service/new_model/inference/`.
- Legacy v1 prototype remains archived in [`ml-service/legacy_v1/`](../legacy_v1/).
