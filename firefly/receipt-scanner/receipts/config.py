"""Settings, read from environment variables (or a .env file)."""

from __future__ import annotations

import json
from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Firefly III
    firefly_url: str = Field(..., description="Base URL of Firefly III, e.g. http://firefly:8080")
    firefly_token: str = Field(..., description="Firefly III personal access token")
    firefly_public_url: str | None = Field(
        None, description="URL you open Firefly at, used for links back to transactions"
    )

    # Claude
    anthropic_api_key: str | None = None  # the SDK also reads ANTHROPIC_API_KEY itself
    receipt_model: str = "claude-opus-5-5"
    receipt_effort: str = "low"

    # Security: every upload must send this secret
    receipts_api_key: str = Field(..., min_length=12)

    # Which Firefly asset account pays for an expense.
    # Keys are payment methods ("Alipay", "WeChat Pay", "card", "cash") or
    # currency codes ("SGD", "CNY"). Values are Firefly asset account names.
    account_map: dict[str, str] = Field(default_factory=dict)
    default_account: str = "Cash wallet"
    default_currency: str = "SGD"
    timezone: str = "Asia/Singapore"
    tag: str = "receipt-scan"

    @field_validator("account_map", mode="before")
    @classmethod
    def _parse_map(cls, v):
        if isinstance(v, str):
            return json.loads(v) if v.strip() else {}
        return v

    def account_for(self, payment_method: str | None, currency: str | None) -> str:
        """Pick the paying account: payment method first, then currency, then default."""
        lookup = {k.lower(): val for k, val in self.account_map.items()}
        for key in (payment_method, currency):
            if key and key.lower() in lookup:
                return lookup[key.lower()]
        return self.default_account


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
