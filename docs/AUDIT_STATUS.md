# Technical audit (17 Nov 2026): status of each finding

The audit reviewed `main` at 0393d36. This is where each finding stands on branch `vitanet-ai-tools`.

| # | Finding | Status | Where |
|---|---|---|---|
| F-01 | Missing triage readings get "normal" defaults | **Fixed**: request schema defaults removed (None), route passes only what was sent, service never fills values; tested | `vitanet-backend/app/schemas/triage.py`, `routes/triage.py`, `services/ml_service.py`, `tests/test_ai_tools.py` |
| F-02 | "ML" triage is a rules/knowledge-base matcher | Open: label it honestly as a rules-based symptom checker in the UI, or replace with the VitaNet model's triage | `services/ml_service.py` |
| F-03 | Failed prediction becomes a self-care result | **Fixed**: failure returns nothing (null); the app says the quick check could not run, gives 112 / 193, and hands the answers to the assistant | `lib/data/services/ai_service.dart`, `assessment_wizard_screen.dart` |
| F-04 | Assessment sends body area as a symptom, drops duration/pain/risk | **Partly fixed**: body area no longer sent as a symptom; duration, pain and risk factors still only reach the chat prompt (the symptom checker has no fields for them) | `assessment_wizard_screen.dart` |
| F-05 | Disconnect leaves old readings in app state | Open | `device_connection_screen.dart`, `providers.dart` |
| F-06 | Permission granted shown as "connected" even if sync failed | **Partly fixed**: sync now goes through one app-wide `VitalsSync` that reads real numbers (the old code never parsed a watch value) and sends the time each reading was measured; separate "permission / read / uploaded" states still to do | `lib/data/services/vitals_sync.dart` |
| F-07 | Profile save not sent to the backend | **Fixed**: every save (and app start) syncs the profile, incl. conditions, medicines, allergies and care-circle contacts | `providers.dart`, `api_service.dart`, `routes/health_profile.py` |
| F-08 | Home location not sent to the backend | **Fixed** | `home_screen.dart`, `providers.dart` |
| F-09 | Backend default URL is a temporary Cloudflare tunnel | Open: needs a stable production address from the owner | `lib/core/network/backend.dart` |
| F-10 | Chat stream lifecycle / error recovery | **Fixed by redesign**: chat is one request to `POST /chat/{uid}` with a 90 s timeout and a clear offline / connection-error reply; no stream to leak | `lib/data/services/ai_service.dart` |
| F-11 | Chat content sent to an external model provider | **Fixed**: Gemini / OpenRouter removed; chat runs on the VitaNet model on our own server | `services/ai_client.py`, `ai_agent.py` |
| F-12 | Portal WebSocket needs integration tests | Open | `portal_live.dart`, `routes/portal_live.py` |

Also done since the audit (not in it): health alerts reach the user and the care circle, SMS line, real videos
and library articles, per-article photos.
