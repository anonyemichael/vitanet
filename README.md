# VitaNet

AI-powered health triage assistant built with Flutter (frontend), FastAPI (backend), and XGBoost (ML prediction).

## Project Structure

```
vitanet/
├── lib/                    # Flutter mobile & web client
│   ├── app/                #   Router, theme, app scaffold
│   ├── core/               #   Constants, extensions, utilities
│   ├── data/               #   Models, providers (Riverpod), services
│   ├── features/           #   Feature modules (chat, home, admin, auth, ...)
│   ├── shared/             #   Shared widgets & utilities
│   └── main.dart           #   App entry point
│
├── vitanet-backend/        # FastAPI backend (PostgreSQL, Firebase Auth)
│   ├── app/
│   │   ├── api/            #   API versioning
│   │   ├── core/           #   Config, Firebase, security
│   │   ├── database/       #   SQLAlchemy connection & base
│   │   ├── dependencies/   #   Auth middleware
│   │   ├── models/         #   ORM models
│   │   ├── routes/         #   Endpoint routers
│   │   ├── schemas/        #   Pydantic request/response schemas
│   │   ├── scripts/        #   Seed & utility scripts
│   │   └── services/       #   Business logic & AI agent
│   ├── alembic/            #   Database migrations
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── ml-service/             # Disease & severity prediction microservice
│   ├── app/                #   FastAPI prediction API
│   ├── notebooks/          #   Jupyter notebooks & trained models (.pkl)
│   ├── data/               #   Training datasets & OpenAPI spec
│   └── requirements.txt
│
├── landing/                # Static landing page (HTML/CSS/JS)
├── scripts/                # Dart & Python utility scripts
├── docs/                   # Project documentation & guides
├── assets/                 # Flutter assets (images, health library data)
└── test/                   # Flutter widget tests
```

## Getting Started

### Flutter Client

```bash
# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on connected device
flutter run
```

### Backend API

```bash
cd vitanet-backend
cp .env.example .env        # Configure your environment variables
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### ML Prediction Service

```bash
cd ml-service
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

### Landing Page

Open `landing/index.html` in a browser, or serve with any static file server.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile & Web | Flutter 3.x, Riverpod, GoRouter |
| Backend API | FastAPI, SQLAlchemy, Alembic, PostgreSQL |
| Authentication | Firebase Auth (Email, Google, Anonymous) |
| Database | Cloud Firestore (client), PostgreSQL (backend) |
| AI Chat | Gemini via OpenRouter, Tavily web search |
| ML Models | XGBoost, scikit-learn, joblib |
| Landing Page | HTML5, CSS3, Vanilla JS |

## Key Features

- **AI Health Triage Chat** — Conversational symptom assessment with context-aware follow-up questions
- **Disease & Severity Prediction** — ML-powered prediction from 377 symptom features and vital signs
- **Live Biometric Integration** — Apple Health / Android Health Connect for HR, SpO2, temperature, BP
- **Care Circles** — Emergency contact management with invitation workflows
- **Health Resource Library** — Curated articles, videos, first-aid guides, and medication search
- **Admin Portal** — Clinical case management, patient monitoring, and hospital dashboards
- **Dual Auth Flows** — Patient (anonymous/email/Google) and health worker registration
