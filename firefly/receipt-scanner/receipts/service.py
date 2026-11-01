"""Glue: image in, Firefly transaction out."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from .config import Settings
from .extractor import Extractor, Receipt
from .firefly import Firefly, FireflyError
from .images import normalize

SYMBOLS = {"SGD": "S$", "CNY": "¥", "USD": "US$", "MYR": "RM", "HKD": "HK$", "EUR": "€", "GBP": "£", "JPY": "¥"}


def money(amount: Decimal | None, currency: str | None) -> str:
    if amount is None:
        return "?"
    return f"{SYMBOLS.get(currency or '', (currency or '') + ' ')}{amount:,.2f}"


@dataclass
class Overrides:
    """Fields the person corrected on the review screen."""

    merchant: str | None = None
    total: Decimal | None = None
    currency: str | None = None
    date: date | None = None
    category: str | None = None
    account: str | None = None
    summary: str | None = None


@dataclass
class Result:
    saved: bool
    message: str
    receipt: Receipt
    account: str | None = None
    transaction_url: str | None = None
    needs_review: bool = False
    accounts: list[str] = field(default_factory=list)
    categories: list[str] = field(default_factory=list)


class ReceiptService:
    def __init__(self, settings: Settings, firefly: Firefly, extractor: Extractor):
        self.s = settings
        self.ff = firefly
        self.ex = extractor

    def today(self) -> date:
        return datetime.now(ZoneInfo(self.s.timezone)).date()

    def overview(self, *, days: int = 31, limit: int = 30) -> dict:
        today = self.today()
        month_start = today.replace(day=1)
        start = min(month_start, today - timedelta(days=days - 1))
        rows = self.ff.withdrawals(start, today)
        rows.sort(key=lambda r: (r["date"], r["id"]), reverse=True)

        totals: dict[str, Decimal] = {}
        by_category: dict[tuple[str, str], Decimal] = {}
        for r in rows:
            if r["date"] < month_start.isoformat():
                continue
            amt = Decimal(r["amount"])
            totals[r["currency"]] = totals.get(r["currency"], Decimal(0)) + amt
            key = (r["category"] or "Uncategorised", r["currency"])
            by_category[key] = by_category.get(key, Decimal(0)) + amt

        return {
            "month": month_start.strftime("%Y-%m"),
            "totals": [{"currency": c, "total": f"{v:.2f}"} for c, v in sorted(totals.items(), key=lambda kv: -kv[1])],
            "by_category": [
                {"category": k[0], "currency": k[1], "total": f"{v:.2f}"}
                for k, v in sorted(by_category.items(), key=lambda kv: -kv[1])
            ],
            "recent": rows[:limit],
        }

    def process(
        self,
        raw: bytes,
        *,
        save: bool = True,
        overrides: Overrides | None = None,
        filename: str = "receipt.jpg",
    ) -> Result:
        jpeg = normalize(raw)
        categories = self.ff.categories()
        accounts = self.ff.asset_account_names()
        if overrides and overrides.total:
            # The person already checked every field on the review screen,
            # so there is no need to pay for a second read.
            receipt = self._apply(Receipt(is_receipt=True, confidence="high"), overrides)
        else:
            receipt = self._apply(self.ex.extract(jpeg, categories), overrides)

        currency = receipt.currency or self.s.default_currency
        account = (overrides and overrides.account) or self.s.account_for(receipt.payment_method, currency)
        base = dict(receipt=receipt, account=account, accounts=accounts, categories=categories)

        if not receipt.is_receipt:
            why = receipt.problem or "it doesn't look like a receipt"
            return Result(saved=False, needs_review=True, message=f"Not saved: {why}.", **base)
        if receipt.total is None or receipt.total <= 0:
            return Result(
                saved=False, needs_review=True,
                message="Not saved: I couldn't read the total. Open the web page to enter it.", **base,
            )
        if receipt.confidence == "low" and not overrides:
            note = f" ({receipt.problem})" if receipt.problem else ""
            return Result(
                saved=False, needs_review=True,
                message=f"Not saved: I'm not sure about this one{note}. Check it on the web page.", **base,
            )
        if account not in accounts:
            raise FireflyError(
                f'There is no asset account called "{account}" in Firefly. '
                f"Create it, or change ACCOUNT_MAP / DEFAULT_ACCOUNT. Accounts found: {', '.join(accounts) or 'none'}."
            )

        summary_line = (
            f"{money(receipt.total, currency)} at {receipt.merchant or 'an unknown shop'}"
            + (f" ({receipt.category})" if receipt.category else "")
        )
        if not save:
            return Result(saved=False, message=f"Read {summary_line}. Not saved yet.", **base)

        description = receipt.merchant or "Receipt"
        if receipt.summary:
            description = f"{description}: {receipt.summary}"
        created = self.ff.create_withdrawal(
            amount=receipt.total,
            currency=currency,
            day=receipt.date or self.today(),
            description=description[:250],
            source_account=account,
            merchant=receipt.merchant,
            category=receipt.category,
            notes=self._notes(receipt, overrides),
            tags=[self.s.tag],
        )
        public = (self.s.firefly_public_url or self.s.firefly_url).rstrip("/")
        message = f"Logged {summary_line} from {account}."
        try:
            self.ff.attach(created.journal_id, filename.rsplit(".", 1)[0] + ".jpg", jpeg)
        except FireflyError:
            # The expense is already saved; don't report failure, or a retry
            # would create it again. Only the picture is missing.
            message += " The receipt image couldn't be attached; add it in Firefly if you need it."
        return Result(
            saved=True,
            message=message,
            transaction_url=f"{public}/transactions/show/{created.group_id}",
            **base,
        )

    @staticmethod
    def _apply(r: Receipt, o: Overrides | None) -> Receipt:
        if not o:
            return r
        changes = {k: v for k, v in vars(o).items() if v not in (None, "") and k != "account"}
        if changes:
            changes.setdefault("is_receipt", True)
        return r.model_copy(update=changes)

    @staticmethod
    def _notes(r: Receipt, o: Overrides | None) -> str:
        source = "checked by you" if o else f"confidence: {r.confidence}"
        lines = [f"Read from a receipt photo by Claude ({source})."]
        if r.payment_method:
            lines.append(f"Paid with: {r.payment_method}")
        if r.problem:
            lines.append(f"Note: {r.problem}")
        return "\n".join(lines)
