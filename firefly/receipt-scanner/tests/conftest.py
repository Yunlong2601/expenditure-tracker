import io
import os

import pytest
import respx
from httpx import Response
from PIL import Image

os.environ.update(
    FIREFLY_URL="http://ff.test",
    FIREFLY_TOKEN="tok",
    RECEIPTS_API_KEY="test-key-123456",
    ACCOUNT_MAP='{"Alipay": "Alipay", "WeChat Pay": "WeChat", "CNY": "Alipay", "SGD": "DBS"}',
    DEFAULT_ACCOUNT="DBS",
    ANTHROPIC_API_KEY="sk-test",
)

from receipts import app as app_module  # noqa: E402
from receipts.config import get_settings  # noqa: E402
from receipts.extractor import Receipt  # noqa: E402
from receipts.firefly import Firefly  # noqa: E402
from receipts.service import ReceiptService  # noqa: E402


class FakeExtractor:
    def __init__(self, receipt: Receipt):
        self.receipt = receipt
        self.calls = 0
        self.seen_categories = None

    def extract(self, jpeg, categories):
        self.calls += 1
        self.seen_categories = categories
        assert jpeg[:2] == b"\xff\xd8"  # always sent as JPEG
        return self.receipt


@pytest.fixture
def png_bytes():
    buf = io.BytesIO()
    Image.new("RGBA", (3000, 2000), (255, 255, 255, 255)).save(buf, format="PNG")
    return buf.getvalue()


@pytest.fixture
def ff():
    with respx.mock(base_url="http://ff.test", assert_all_called=False) as mock:
        mock.get("/api/v1/categories").mock(return_value=Response(200, json={
            "data": [{"attributes": {"name": "Food & drink"}}, {"attributes": {"name": "Transport"}}],
            "meta": {"pagination": {"total_pages": 1}},
        }))
        mock.get("/api/v1/accounts").mock(return_value=Response(200, json={
            "data": [{"attributes": {"name": n}} for n in ("DBS", "Alipay", "WeChat")],
            "meta": {"pagination": {"total_pages": 1}},
        }))
        mock.post("/api/v1/transactions").mock(return_value=Response(200, json={
            "data": {"id": "42", "attributes": {"transactions": [{"transaction_journal_id": "99"}]}},
        }))
        mock.post("/api/v1/attachments").mock(return_value=Response(200, json={"data": {"id": "7"}}))
        mock.post("/api/v1/attachments/7/upload").mock(return_value=Response(204))
        yield mock


@pytest.fixture
def make_client():
    from fastapi.testclient import TestClient

    def _make(receipt: Receipt):
        s = get_settings()
        fake = FakeExtractor(receipt)
        svc = ReceiptService(s, Firefly(s.firefly_url, s.firefly_token), fake)
        app_module.app.dependency_overrides[app_module.get_service] = lambda: svc
        return TestClient(app_module.app), fake

    yield _make
    app_module.app.dependency_overrides.clear()
