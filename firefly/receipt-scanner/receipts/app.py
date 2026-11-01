"""HTTP API and phone-friendly upload page."""

from __future__ import annotations

import hmac
import logging
from datetime import date
from decimal import Decimal, InvalidOperation
from functools import lru_cache
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse

from .config import Settings, get_settings
from .extractor import ClaudeExtractor, ExtractionError
from .firefly import DuplicateTransaction, Firefly, FireflyError
from .images import BadImage
from .service import Overrides, ReceiptService, Result

log = logging.getLogger("receipts")
STATIC = Path(__file__).parent / "static"

app = FastAPI(title="Firefly receipt scanner", docs_url=None, redoc_url=None)


@lru_cache
def _service() -> ReceiptService:
    s = get_settings()
    return ReceiptService(
        s,
        Firefly(s.firefly_url, s.firefly_token),
        ClaudeExtractor(s.receipt_model, s.receipt_effort),
    )


def get_service() -> ReceiptService:
    return _service()


def check_key(
    x_api_key: str | None = Header(None),
    settings: Settings = Depends(get_settings),
) -> None:
    if not x_api_key or not hmac.compare_digest(x_api_key, settings.receipts_api_key):
        raise HTTPException(401, "Wrong or missing X-Api-Key.")


def _dec(v: str | None) -> Decimal | None:
    if not v:
        return None
    try:
        return abs(Decimal(v.replace(",", "")))
    except InvalidOperation:
        raise HTTPException(422, "The amount isn't a number.")


def _date(v: str | None) -> date | None:
    if not v:
        return None
    try:
        return date.fromisoformat(v)
    except ValueError:
        raise HTTPException(422, "The date must look like 2026-11-01.")


def _payload(r: Result) -> dict:
    rc = r.receipt
    return {
        "saved": r.saved,
        "needs_review": r.needs_review,
        "message": r.message,
        "transaction_url": r.transaction_url,
        "account": r.account,
        "accounts": r.accounts,
        "categories": r.categories,
        "receipt": {
            "merchant": rc.merchant,
            "total": str(rc.total) if rc.total is not None else None,
            "currency": rc.currency,
            "date": rc.date.isoformat() if rc.date else None,
            "category": rc.category,
            "payment_method": rc.payment_method,
            "summary": rc.summary,
            "confidence": rc.confidence,
            "problem": rc.problem,
        },
    }


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    return (STATIC / "index.html").read_text(encoding="utf-8")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/api/receipt", dependencies=[Depends(check_key)])
async def receipt(
    request: Request,
    save: bool = Query(True, description="false = read only, don't create the expense"),
    format: str = Query("json", pattern="^(json|text)$"),
    service: ReceiptService = Depends(get_service),
):
    """Accept a multipart form (field "file" plus optional corrected fields from
    the review page) or a raw image body of any content type (iPhone Shortcut)."""
    form: dict = {}
    filename = "receipt.jpg"
    if request.headers.get("content-type", "").startswith("multipart/form-data"):
        data = await request.form()
        upload = data.get("file")
        if upload is None or isinstance(upload, str):
            raise HTTPException(422, 'Send the image in a form field called "file".')
        raw, filename = await upload.read(), upload.filename or filename
        form = {k: v for k, v in data.items() if isinstance(v, str)}
    else:
        raw = await request.body()

    fields = dict(
        merchant=form.get("merchant") or None,
        total=_dec(form.get("total")),
        currency=(form.get("currency") or "").strip().upper() or None,
        date=_date(form.get("date")),
        category=form.get("category") or None,
        account=form.get("account") or None,
        summary=form.get("summary") or None,
    )
    overrides = Overrides(**fields) if any(v is not None for v in fields.values()) else None

    try:
        result = service.process(raw, save=save, overrides=overrides, filename=filename)
        status, body = 200, _payload(result)
    except BadImage as exc:
        status, body = 400, {"saved": False, "message": str(exc)}
    except DuplicateTransaction as exc:
        status, body = 409, {"saved": False, "message": str(exc)}
    except (ExtractionError, FireflyError) as exc:
        log.warning("receipt failed: %s", exc)
        status, body = 502, {"saved": False, "message": str(exc)}

    if format == "text":
        return PlainTextResponse(body["message"], status_code=status)
    return JSONResponse(body, status_code=status)
