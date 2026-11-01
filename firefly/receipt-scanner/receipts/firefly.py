"""Minimal Firefly III API client: just what the receipt scanner needs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal

import httpx


class FireflyError(RuntimeError):
    pass


class DuplicateTransaction(FireflyError):
    pass


@dataclass
class Created:
    group_id: str
    journal_id: str


class Firefly:
    def __init__(self, base_url: str, token: str, client: httpx.Client | None = None):
        self.base = base_url.rstrip("/")
        self.http = client or httpx.Client(timeout=30)
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.api+json",
        }

    def _get_all(self, path: str, params: dict | None = None) -> list[dict]:
        items, page = [], 1
        while True:
            r = self.http.get(
                f"{self.base}/api/v1/{path}",
                params={**(params or {}), "page": page, "limit": 100},
                headers=self.headers,
            )
            self._raise(r)
            body = r.json()
            items.extend(body.get("data", []))
            pagination = body.get("meta", {}).get("pagination", {})
            if page >= pagination.get("total_pages", 1):
                return items
            page += 1

    def withdrawals(self, start: date, end: date, max_items: int = 500) -> list[dict]:
        """Expense splits between two dates (inclusive), newest first."""
        out: list[dict] = []
        page = 1
        while len(out) < max_items:
            r = self.http.get(
                f"{self.base}/api/v1/transactions",
                params={"type": "withdrawal", "start": start.isoformat(), "end": end.isoformat(),
                        "page": page, "limit": 100},
                headers=self.headers,
            )
            self._raise(r)
            body = r.json()
            for group in body.get("data", []):
                for t in group["attributes"]["transactions"]:
                    out.append({
                        "id": str(group["id"]),
                        "date": t["date"][:10],
                        "amount": str(abs(Decimal(t["amount"]))),
                        "currency": t["currency_code"],
                        "description": t.get("description"),
                        "merchant": t.get("destination_name"),
                        "category": t.get("category_name"),
                        "account": t.get("source_name"),
                        "has_receipt": bool(t.get("has_attachments")),
                    })
            if page >= body.get("meta", {}).get("pagination", {}).get("total_pages", 1):
                break
            page += 1
        return out[:max_items]

    def categories(self) -> list[str]:
        return sorted(c["attributes"]["name"] for c in self._get_all("categories"))

    def asset_account_names(self) -> list[str]:
        return [a["attributes"]["name"] for a in self._get_all("accounts", {"type": "asset"})]

    def create_withdrawal(
        self,
        *,
        amount: Decimal,
        currency: str,
        day: date,
        description: str,
        source_account: str,
        merchant: str | None,
        category: str | None,
        notes: str | None,
        tags: list[str],
    ) -> Created:
        split = {
            "type": "withdrawal",
            "date": day.isoformat(),
            "amount": str(amount),
            "currency_code": currency,
            "description": description,
            "source_name": source_account,
            "destination_name": merchant or "(unknown shop)",
            "category_name": category,
            "notes": notes,
            "tags": tags,
        }
        payload = {
            "error_if_duplicate_hash": True,
            "apply_rules": True,
            "fire_webhooks": True,
            "transactions": [{k: v for k, v in split.items() if v not in (None, "", [])}],
        }
        r = self.http.post(
            f"{self.base}/api/v1/transactions",
            json=payload,
            headers={**self.headers, "Content-Type": "application/json"},
        )
        if r.status_code == 422 and "duplicate" in r.text.lower():
            raise DuplicateTransaction("This expense is already in Firefly.")
        self._raise(r)
        data = r.json()["data"]
        journal = data["attributes"]["transactions"][0]["transaction_journal_id"]
        return Created(group_id=str(data["id"]), journal_id=str(journal))

    def attach(self, journal_id: str, filename: str, content: bytes) -> None:
        r = self.http.post(
            f"{self.base}/api/v1/attachments",
            json={
                "filename": filename,
                "attachable_type": "TransactionJournal",
                "attachable_id": journal_id,
                "title": "Receipt",
            },
            headers={**self.headers, "Content-Type": "application/json"},
        )
        self._raise(r)
        attachment_id = r.json()["data"]["id"]
        r = self.http.post(
            f"{self.base}/api/v1/attachments/{attachment_id}/upload",
            content=content,
            headers={**self.headers, "Content-Type": "application/octet-stream"},
        )
        self._raise(r)

    @staticmethod
    def _raise(r: httpx.Response) -> None:
        if r.status_code == 401:
            raise FireflyError("Firefly rejected the access token.")
        if r.is_error:
            try:
                message = r.json().get("message") or r.text
            except ValueError:
                message = r.text
            raise FireflyError(f"Firefly returned {r.status_code}: {message[:300]}")
