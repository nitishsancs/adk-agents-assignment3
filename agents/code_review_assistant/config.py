"""Validated settings, read from the environment (and the repo .env loaded in __init__)."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", extra="ignore")

    worker_model: str = Field(default="gemini-flash-latest", alias="FAST_MODEL")
    critic_model: str = Field(default="gemini-flash-latest", alias="SMART_MODEL")
    max_line_length: int = Field(default=100, alias="REVIEW_MAX_LINE_LENGTH")
    max_function_length: int = Field(default=50, alias="REVIEW_MAX_FUNCTION_LENGTH")
    max_complexity: int = Field(default=10, alias="REVIEW_MAX_COMPLEXITY")
    target_style_score: int = Field(default=90, alias="REVIEW_TARGET_STYLE_SCORE")
    max_fix_attempts: int = Field(default=3, alias="REVIEW_MAX_FIX_ATTEMPTS")


settings = Settings()
