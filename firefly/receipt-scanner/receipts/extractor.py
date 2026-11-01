"""Read a receipt or payment screenshot with Claude and return structured data."""

from __future__ import annotations

import base64
import json
import datetime as dt
from decimal import Decimal, InvalidOperation
from typing import Literal, Protocol

import anthropic
from pydantic import BaseModel, field_validator

PAYMENT_METHODS = ["card", "cash", "Alipay", "WeChat Pay", "PayNow", "GrabPay", "bank transfer", "other"]

SCHEMA = {
    "type": "object",
    "properties": {
        "is_receipt": {
            "type": "boolean",
            "description": "True if the image shows a purchase: a receipt, invoice, or payment confirmation.",
        },
        "merchant": {"type": ["string", "null"], "description": "Shop or payee name, as printed."},
        "total": {
            "type": ["string", "null"],
            "description": "Final amount paid, digits and a dot only, e.g. \"12.80\". Use the grand total after tax, service charge and discounts.",
        },
        "currency": {
            "type": ["string", "null"],
            "description": "ISO 4217 code, e.g. SGD, CNY, MYR, USD.",
        },
        "date": {"type": ["string", "null"], "description": "Purchase date as YYYY-MM-DD, if shown."},
        "category": {"type": ["string", "null"], "description": "Spending category for this purchase."},
        "payment_method": {
            "type": ["string", "null"],
            "description": "How it was paid, one of: " + ", ".join(PAYMENT_METHODS) + ". Null if not shown.",
        },
        "summary": {
            "type": ["string", "null"],
            "description": "A few words on what was bought, e.g. \"2x kopi, kaya toast\".",
        },
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
        "problem": {
            "type": ["string", "null"],
            "description": "If something is unclear (blurry total, several totals, not a receipt), say what.",
        },
    },
    "required": [
        "is_receipt", "merchant", "total", "currency", "date", "category",
        "payment_method", "summary", "confidence", "problem",
    ],
    "additionalProperties": False,
}

SYSTEM = """You read receipts and payment screenshots for a personal expense tracker.
The owner lives in Singapore and sometimes spends in China, so expect English and
Chinese text, SGD and CNY, and screenshots from Alipay (支付宝), WeChat Pay (微信支付),
PayNow, GrabPay, and Singapore bank apps.

Rules:
- total is what the person actually paid. On Singapore receipts that is usually the
  line after GST and service charge. On Alipay or WeChat screenshots it is the large
  number at the top (ignore the minus sign).
- Infer currency from symbols and context: "S$" or a Singapore address means SGD;
  "¥" or "￥" with Chinese text means CNY; a bare "$" in Singapore means SGD.
- If there is no date on the image, leave date null.
- Pick category from the existing categories when one fits; otherwise suggest a short
  new one (e.g. "Food & drink", "Transport", "Groceries", "Shopping", "Bills").
- Put the merchant name in its original language if that is how it is printed.
- If the image is not a purchase at all, set is_receipt to false and explain in problem."""


class Receipt(BaseModel):
    is_receipt: bool
    merchant: str | None = None
    total: Decimal | None = None
    currency: str | None = None
    date: dt.date | None = None
    category: str | None = None
    payment_method: str | None = None
    summary: str | None = None
    confidence: Literal["high", "medium", "low"] = "low"
    problem: str | None = None

    @field_validator("total", mode="before")
    @classmethod
    def _total(cls, v):
        if v in (None, ""):
            return None
        try:
            return abs(Decimal(str(v).replace(",", "").strip()))
        except InvalidOperation:
            return None

    @field_validator("date", mode="before")
    @classmethod
    def _date(cls, v):
        if not v:
            return None
        try:
            return dt.date.fromisoformat(str(v))
        except ValueError:
            return None

    @field_validator("currency", mode="before")
    @classmethod
    def _currency(cls, v):
        if not v:
            return None
        v = str(v).strip().upper()
        return {"RMB": "CNY", "S$": "SGD"}.get(v, v)


class ExtractionError(RuntimeError):
    pass


class Extractor(Protocol):
    def extract(self, jpeg: bytes, categories: list[str]) -> Receipt: ...


class ClaudeExtractor:
    def __init__(self, model: str, effort: str = "low", client: anthropic.Anthropic | None = None):
        self.model = model
        self.effort = effort
        self.client = client or anthropic.Anthropic()

    def extract(self, jpeg: bytes, categories: list[str]) -> Receipt:
        known = ", ".join(categories) if categories else "(none yet)"
        try:
            response = self.client.beta.messages.create(
                model=self.model,
                max_tokens=16000,
                system=SYSTEM,
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
                output_config={
                    "effort": self.effort,
                    "format": {"type": "json_schema", "schema": SCHEMA},
                },
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": base64.standard_b64encode(jpeg).decode(),
                                },
                            },
                            {"type": "text", "text": f"Existing categories: {known}\n\nRead this purchase."},
                        ],
                    }
                ],
            )
        except anthropic.AuthenticationError as exc:
            raise ExtractionError("The Anthropic API key was rejected.") from exc
        except anthropic.RateLimitError as exc:
            raise ExtractionError("Too many requests to Claude right now. Try again in a minute.") from exc
        except anthropic.APIStatusError as exc:
            raise ExtractionError(f"Claude returned an error ({exc.status_code}).") from exc
        except anthropic.APIConnectionError as exc:
            raise ExtractionError("Couldn't reach Claude. Check the server's internet connection.") from exc

        if response.stop_reason == "refusal":
            raise ExtractionError("Claude declined to read this image.")
        if response.stop_reason == "max_tokens":
            raise ExtractionError("Claude's answer was cut off. Try again.")
        text = next((b.text for b in response.content if b.type == "text"), None)
        if not text:
            raise ExtractionError("Claude returned no answer.")
        try:
            return Receipt.model_validate(json.loads(text))
        except (json.JSONDecodeError, ValueError) as exc:
            raise ExtractionError("Claude's answer couldn't be parsed.") from exc
