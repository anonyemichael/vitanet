from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "VitaNet API"
    ENVIRONMENT: str = "development"
    DATABASE_URL: str = "sqlite:///./vitanet.db"
    DEV_BYPASS_AUTH: bool = True
    FIREBASE_CREDENTIALS_PATH: str = ""
    RESEND_API_KEY: str = ""
    
    # The VitaNet model (OpenAI-compatible server, e.g. vLLM). Gemini / OpenRouter are no longer used.
    # Empty AI_BASE_URL = the assistant is offline: the app is told so, danger-sign warnings and triage still work.
    AI_BASE_URL: str = ""            # e.g. http://<model-server>:8000/v1
    AI_MODEL: str = "vitanet-27b"
    AI_API_KEY: str = ""
    AI_TIMEOUT_S: float = 60.0

    # Hospital-portal model (the 5 JSON tasks). Empty URL = the portal uses its rule-based output only.
    PORTAL_AI_URL: str = ""
    PORTAL_AI_MODEL: str = "vitanet-27b"
    PORTAL_AI_KEY: str = ""
    PORTAL_AI_TIMEOUT_S: float = 20.0

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
