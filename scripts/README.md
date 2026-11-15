# VitaNet Scripts Directory

This directory contains utility scripts for maintenance, deployment, and testing.

## Active Scripts

| Script | Purpose |
|--------|---------|
| `deploy_backend.ps1` | Production backend deployment and service configuration script. |
| `download_assets.dart` | Utility to fetch and verify remote asset files (images, medical graphics). |
| `remove_white.ps1` | Image asset background removal utility. |
| `set_backend_url.ps1` | Configures local/remote backend URL for Flutter development. |
| `test_api.dart` | Smoke test script for backend API connectivity. |
| `test_health.dart` | Health-check probe for the backend service. |

## Archive (`scripts/archive/`)

Contains historical one-off utilities, data migration scripts, and external API test dumps:
- `movie_bot_v5.py`: Historical utility (unrelated terminal bot).
- `extract.dart`: One-off transcript log parser.
- `fix_json.dart`: One-off health library JSON cleanup script.
- `list_models.dart`, `test_openrouter.dart`, `test_overpass.dart`: One-time external API tests.
- `models.json`, `models_utf8.json`: Cached OpenRouter API model listings.
