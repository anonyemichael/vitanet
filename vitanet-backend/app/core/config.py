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

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
