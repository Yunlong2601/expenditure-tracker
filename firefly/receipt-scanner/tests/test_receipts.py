import json
from decimal import Decimal

from receipts.config import get_settings
from receipts.extractor import Receipt
from receipts.images import normalize

KEY = {"X-Api-Key": "test-key-123456"}

KOPI = Receipt(is_receipt=True, merchant="Ya Kun Kaya Toast", total="7.40", currency="SGD",
               date="2026-10-30", category="Food & drink", payment_method="card",
               summary="kaya toast set", confidence="high")


def test_normalize_shrinks_and_converts(png_bytes):
    from PIL import Image
    import io
    out = normalize(png_bytes)
    img = Image.open(io.BytesIO(out))
    assert img.format == "JPEG" and max(img.size) == 1568


def test_receipt_cleans_values():
    r = Receipt(is_receipt=True, total="-1,234.50", currency="rmb", date="not a date")
    assert r.total == Decimal("1234.50") and r.currency == "CNY" and r.date is None


def test_account_mapping():
    s = get_settings()
    assert s.account_for("WeChat Pay", "CNY") == "WeChat"
    assert s.account_for(None, "CNY") == "Alipay"
    assert s.account_for("cash", "MYR") == "DBS"


def test_requires_key(make_client, ff, png_bytes):
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt", content=png_bytes)
    assert r.status_code == 401


def test_raw_body_upload_creates_expense_with_attachment(make_client, ff, png_bytes):
    client, fake = make_client(KOPI)
    r = client.post("/api/receipt?format=text", content=png_bytes, headers=KEY)
    assert r.status_code == 200, r.text
    assert r.text == "Logged S$7.40 at Ya Kun Kaya Toast (Food & drink) from DBS."
    assert fake.seen_categories == ["Food & drink", "Transport"]

    tx = next(c.request for c in ff.calls if c.request.url.path == "/api/v1/transactions")
    body = json.loads(tx.content)
    split = body["transactions"][0]
    assert body["error_if_duplicate_hash"] is True
    assert split == {
        "type": "withdrawal", "date": "2026-10-30", "amount": "7.40", "currency_code": "SGD",
        "description": "Ya Kun Kaya Toast: kaya toast set", "source_name": "DBS",
        "destination_name": "Ya Kun Kaya Toast", "category_name": "Food & drink",
        "notes": split["notes"], "tags": ["receipt-scan"],
    }
    upload = next(c.request for c in ff.calls if c.request.url.path.endswith("/upload"))
    assert upload.content[:2] == b"\xff\xd8"


def test_alipay_goes_to_alipay_account(make_client, ff, png_bytes):
    alipay = KOPI.model_copy(update={"merchant": "瑞幸咖啡", "total": Decimal("19.9"), "currency": "CNY",
                                     "payment_method": "Alipay"})
    client, _ = make_client(alipay)
    r = client.post("/api/receipt", files={"file": ("a.png", png_bytes, "image/png")}, headers=KEY)
    assert r.json()["saved"] is True
    assert r.json()["message"] == "Logged ¥19.90 at 瑞幸咖啡 (Food & drink) from Alipay."


def test_low_confidence_is_not_saved(make_client, ff, png_bytes):
    client, _ = make_client(KOPI.model_copy(update={"confidence": "low", "problem": "total is blurry"}))
    r = client.post("/api/receipt", content=png_bytes, headers=KEY)
    assert r.json()["saved"] is False and "total is blurry" in r.json()["message"]
    assert not any(c.request.url.path == "/api/v1/transactions" for c in ff.calls)


def test_not_a_receipt(make_client, ff, png_bytes):
    client, _ = make_client(Receipt(is_receipt=False, problem="it's a photo of a cat"))
    r = client.post("/api/receipt?format=text", content=png_bytes, headers=KEY)
    assert r.text == "Not saved: it's a photo of a cat."


def test_preview_does_not_save(make_client, ff, png_bytes):
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt?save=false", content=png_bytes, headers=KEY)
    body = r.json()
    assert body["saved"] is False and body["receipt"]["total"] == "7.40"
    assert body["accounts"] == ["DBS", "Alipay", "WeChat"]
    assert not any(c.request.url.path == "/api/v1/transactions" for c in ff.calls)


def test_reviewed_fields_skip_second_read(make_client, ff, png_bytes):
    client, fake = make_client(KOPI)
    r = client.post("/api/receipt", headers=KEY,
                    files={"file": ("a.jpg", png_bytes, "image/jpeg")},
                    data={"merchant": "Kopitiam", "total": "5.20", "currency": "sgd",
                          "date": "2026-11-01", "category": "Food & drink", "account": "DBS"})
    assert r.json()["saved"] is True, r.json()
    assert fake.calls == 0
    tx = next(c.request for c in ff.calls if c.request.url.path == "/api/v1/transactions")
    split = json.loads(tx.content)["transactions"][0]
    assert (split["amount"], split["date"], split["destination_name"]) == ("5.20", "2026-11-01", "Kopitiam")


def test_duplicate_is_reported(make_client, ff, png_bytes):
    from httpx import Response
    ff.post("/api/v1/transactions").mock(return_value=Response(422, json={"message": "Duplicate of transaction #4."}))
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt", content=png_bytes, headers=KEY)
    assert r.status_code == 409 and r.json()["message"] == "This expense is already in Firefly."


def test_missing_account_gives_clear_error(make_client, ff, png_bytes):
    client, _ = make_client(KOPI.model_copy(update={"payment_method": "WeChat Pay"}))
    from httpx import Response
    ff.get("/api/v1/accounts").mock(return_value=Response(200, json={
        "data": [{"attributes": {"name": "DBS"}}], "meta": {"pagination": {"total_pages": 1}}}))
    r = client.post("/api/receipt", content=png_bytes, headers=KEY)
    assert r.status_code == 502 and 'no asset account called "WeChat"' in r.json()["message"]


def test_bad_image(make_client, ff):
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt", content=b"hello", headers=KEY)
    assert r.status_code == 400


def test_upload_page(make_client):
    client, _ = make_client(KOPI)
    assert "Scan a receipt" in client.get("/").text


def test_raw_body_with_form_content_type(make_client, ff, png_bytes):
    # curl --data-binary and some Shortcut setups label raw bytes as a form
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt", content=png_bytes,
                    headers={**KEY, "Content-Type": "application/x-www-form-urlencoded"})
    assert r.status_code == 200 and r.json()["saved"] is True


def test_attachment_failure_still_reports_saved(make_client, ff, png_bytes):
    from httpx import Response
    ff.post("/api/v1/attachments").mock(return_value=Response(500, json={"message": "disk full"}))
    client, _ = make_client(KOPI)
    r = client.post("/api/receipt", content=png_bytes, headers=KEY)
    body = r.json()
    assert r.status_code == 200 and body["saved"] is True
    assert body["transaction_url"].endswith("/transactions/show/42")
    assert "couldn't be attached" in body["message"]


def test_expenses_overview(make_client, ff):
    from httpx import Response
    def tx(i, d, amt, cur, cat):
        return {"id": str(i), "attributes": {"transactions": [{
            "date": d + "T12:00:00+08:00", "amount": amt, "currency_code": cur, "description": "x",
            "destination_name": "Shop", "category_name": cat, "source_name": "DBS", "has_attachments": True}]}}
    import receipts.service as svc
    ff.get("/api/v1/transactions").mock(return_value=Response(200, json={
        "data": [tx(1, "2026-11-01", "7.40", "SGD", "Food & drink"), tx(2, "2026-11-02", "12.60", "SGD", "Food & drink"),
                 tx(3, "2026-11-02", "19.90", "CNY", None), tx(4, "2026-10-20", "100.00", "SGD", "Bills")],
        "meta": {"pagination": {"total_pages": 1}}}))
    client, _ = make_client(KOPI)
    from datetime import date
    orig = svc.ReceiptService.today
    svc.ReceiptService.today = lambda self: date(2026, 11, 3)
    try:
        r = client.get("/api/expenses", headers=KEY)
    finally:
        svc.ReceiptService.today = orig
    body = r.json()
    assert body["month"] == "2026-11"
    assert body["totals"] == [{"currency": "SGD", "total": "20.00"}, {"currency": "CNY", "total": "19.90"}]
    assert {"category": "Uncategorised", "currency": "CNY", "total": "19.90"} in body["by_category"]
    assert [x["id"] for x in body["recent"]] == ["3", "2", "1", "4"]
    assert client.get("/api/expenses").status_code == 401
