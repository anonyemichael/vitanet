# Technical audit (17 Nov 2026): status of each finding

The audit reviewed `main` at 0393d36. This is where each finding stands on branch `vitanet-ai-tools`.

| # | Finding | Status | Where |
|---|---|---|---|
| F-01 | Missing triage readings get "normal" defaults | **Fixed**: request schema defaults removed (None), route passes only what was sent, service never fills values; tested | `vitanet-backend/app/schemas/triage.py`, `routes/triage.py`, `services/ml_service.py`, `tests/test_ai_tools.py` |
| F-02 | "ML" triage is a rules/knowledge-base matcher | **Fixed**: invented percentages removed; it reports "strong / partial / weak / no clear match", the rule that set the urgency, and `method: rules-based symptom checker (not a trained model, not a diagnosis)`; the app says "Quick symptom checker, not a diagnosis" | `services/ml_service.py`, `schemas/triage.py`, `ai_service.dart` |
| F-03 | Failed prediction becomes a self-care result | **Fixed**: failure returns nothing (null); the app says the quick check could not run, gives 112 / 193, and hands the answers to the assistant | `lib/data/services/ai_service.dart`, `assessment_wizard_screen.dart` |
| F-04 | Assessment sends body area as a symptom, drops duration/pain/risk | **Fixed**: body area sent as its own field, not a symptom; pain, duration (days) and risk factors sent and used; they can only raise urgency (pain ≥ 8, 14+ days, any risk factor → see a clinician; fever + stiff neck / confusion → urgent; marked for clinical review); tested | `assessment_wizard_screen.dart`, `schemas/triage.py`, `ml_service.py` |
| F-05 | Disconnect leaves old readings in app state | **Fixed**: disconnect clears the readings everywhere (dashboard, triage), stops all syncing and remembers that after a restart; points to Health Connect / Apple Health to remove access (an app cannot revoke it itself) | `device_connection_screen.dart`, `vitals_sync.dart`, `providers.dart` |
| F-06 | Permission granted shown as "connected" even if sync failed | **Fixed**: each sync records permission, readings read, readings saved and the error; "connected" only after a real read; messages say exactly which step failed (e.g. read 3 but could not save) | `vitals_sync.dart`, `health_service.dart`, `device_connection_screen.dart` |
| F-07 | Profile save not sent to the backend | **Fixed**: every save (and app start) syncs the profile, incl. conditions, medicines, allergies and care-circle contacts | `providers.dart`, `api_service.dart`, `routes/health_profile.py` |
| F-08 | Home location not sent to the backend | **Fixed** | `home_screen.dart`, `providers.dart` |
| F-09 | Backend default URL is a temporary Cloudflare tunnel | Open: needs a stable production address from the owner | `lib/core/network/backend.dart` |
| F-10 | Chat stream lifecycle / error recovery | **Fixed by redesign**: chat is one request to `POST /chat/{uid}` with a 90 s timeout and a clear offline / connection-error reply; no stream to leak | `lib/data/services/ai_service.dart` |
| F-11 | Chat content sent to an external model provider | **Fixed**: Gemini / OpenRouter removed; chat runs on the VitaNet model on our own server | `services/ai_client.py`, `ai_agent.py` |
| F-12 | Portal WebSocket needs integration tests | **Tested**: bad / expired token (4401), unapproved or non-staff (4403), events reach every phone of the right hospital and no other, unknown event types dropped, keep-alive ping, closed phones unsubscribed | `tests/test_portal_live.py` |

**Left: F-09 only** (needs the owner's permanent server address).

Also done since the audit (not in it): health alerts reach the user and the care circle, SMS line, real videos
and library articles, per-article photos.
