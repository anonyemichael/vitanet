from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str
    ENVIRONMENT: str
    DATABASE_URL: str
    DEV_BYPASS_AUTH: bool = False
    FIREBASE_CREDENTIALS_PATH: str
    RESEND_API_KEY: str
    
    GEMINI_API_KEY: str

    class Config:
        env_file = ".env"


settings = Settings()