"""Configuration management for LLM Gateway."""
from typing import Literal, List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    # Ollama backend configuration
    ollama_base_url: str = "http://ollama.svc.cluster.local:11434"
    request_timeout_seconds: int = 30
    max_retries: int = 2

    # Model configuration
    allowed_models: str = ""  # Comma-separated list
    default_model: str = "llama2"

    # Policy enforcement
    enforcement_mode: Literal["monitor", "soft", "hard"] = "monitor"
    allowed_tools: str = ""  # Comma-separated list
    high_risk_tools: str = ""  # Comma-separated list requiring approval

    # Security
    require_api_key: bool = False
    api_key: str = ""

    # Logging
    log_level: str = "INFO"
    log_raw_prompts: bool = False  # Security: avoid logging sensitive data

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    @property
    def allowed_models_list(self) -> List[str]:
        """Parse allowed models from comma-separated string."""
        if not self.allowed_models:
            return [self.default_model]
        return [m.strip() for m in self.allowed_models.split(",") if m.strip()]

    @property
    def allowed_tools_list(self) -> List[str]:
        """Parse allowed tools from comma-separated string."""
        if not self.allowed_tools:
            return []
        return [t.strip() for t in self.allowed_tools.split(",") if t.strip()]

    @property
    def high_risk_tools_list(self) -> List[str]:
        """Parse high-risk tools from comma-separated string."""
        if not self.high_risk_tools:
            return []
        return [t.strip() for t in self.high_risk_tools.split(",") if t.strip()]


# Global settings instance
settings = Settings()
