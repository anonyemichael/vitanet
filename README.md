# Vitanet

Vitanet is a comprehensive health and wellness application built with Flutter (frontend) and Python/FastAPI (backend). 

## Features
- **Patient & Admin Portals**: Separate interfaces and workflows for patients and administrators.
- **AI Health Agent**: Chatbot integration for health and wellness advice.
- **Health Profile & Vitals**: Track respiratory rate and other vital signs.
- **Resources**: First aid instructions, health library, and video resources.

## Project Structure
- `/lib` - Flutter frontend code.
- `/vitanet-backend` - FastAPI backend application.
- `/scripts` - Utility scripts for data extraction, formatting, and bot interactions.
- `/data` - JSON data files for models and openapi specs.
- `/logs` - Output log files from Flutter.

## Getting Started
To run the Flutter app:
```bash
flutter run
```

To run the backend:
```bash
cd vitanet-backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```
