from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "VitaNet API"
    ENVIRONMENT: str = "development"
    DATABASE_URL: str = "sqlite:///./vitanet.db"
    DEV_BYPASS_AUTH: bool = True
    FIREBASE_CREDENTIALS_PATH: str = ""
    RESEND_API_KEY: str = ""
    # Sender for care-circle invites and alert emails. Resend's test sender only delivers to your own address;
    # verify your domain in Resend and set e.g. "VitaNet <alerts@yourdomain.com>".
    EMAIL_FROM: str = "VitaNet <onboarding@resend.dev>"
    
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

    # SMS line (Africa's Talking). Empty AT_API_KEY = replies are worked out but not sent.
    AT_USERNAME: str = "sandbox"
    AT_API_KEY: str = ""
    AT_SHORTCODE: str = ""           # your short code / sender id, e.g. "12345"
    SMS_WEBHOOK_TOKEN: str = ""      # if set, the callback URL must end with ?token=<this>
    SMS_HASH_SECRET: str = ""        # phone numbers are stored only as a keyed hash; set a long random string
    SMS_MAX_PER_HOUR: int = 15       # replies per phone number per hour (each SMS costs money)
    SMS_MAX_SEGMENTS: int = 3        # longest reply, in SMS parts

    # Health alerts: an urgent alert nobody answers in the app is sent to the care circle after this many minutes.
    ALERT_ESCALATION_MINUTES: int = 10
    # Health videos (Learn / Clips pages): free YouTube Data API v3 key, used only on the server.
    YOUTUBE_API_KEY: str = ""
    # Health library photos: free Pexels API key (pexels.com/api), server only. Empty = app topic photos.
    PEXELS_API_KEY: str = ""

    # Public address of this server (links in care-circle invite emails).
    PUBLIC_BASE_URL: str = "http://localhost:8000"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
