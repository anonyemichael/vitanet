from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "VitaNet API"
    ENVIRONMENT: str = "development"
    DATABASE_URL: str = "sqlite:///./vitanet.db"
    DEV_BYPASS_AUTH: bool = True
    FIREBASE_CREDENTIALS_PATH: str = ""
    RESEND_API_KEY: str = ""
    
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"
    OPENROUTER_API_KEYS: str = ""

    # Chat model (OpenAI-compatible). Default: Gemini via OpenRouter. For the VitaNet model served with vLLM, set
    # AI_BASE_URL=http://<server>:8000/v1, AI_MODEL=vitanet-27b, AI_API_KEY=<server key>.
    AI_BASE_URL: str = "https://openrouter.ai/api/v1"
    AI_MODEL: str = "google/gemini-2.5-flash"
    AI_API_KEY: str = ""

    # Hospital-portal model (the 5 JSON tasks). Empty URL = the portal uses its rule-based output only.
    PORTAL_AI_URL: str = ""
    PORTAL_AI_MODEL: str = "vitanet-27b"
    PORTAL_AI_KEY: str = ""
    PORTAL_AI_TIMEOUT_S: float = 20.0

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
