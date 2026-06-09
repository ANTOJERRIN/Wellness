from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Med Genie API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api"
    
    # Security
    JWT_SECRET: str = "super-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 Days
    
    # Database
    DATABASE_URL: str = "sqlite:///./dev.db"
    
    # Gemini AI
    GOOGLE_AI_API_KEY: str = ""

    # OGD Hospital API (data.gov.in)
    API_SETU_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Allow extra env variables without failing validation

settings = Settings()
