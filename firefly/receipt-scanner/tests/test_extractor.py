import json

import anthropic
import httpx2
import pytest

from receipts.extractor import ExtractionError

from receipts.extractor import ClaudeExtractor


def _client(reply, seen):
    def handler(request):
        seen.append(request)
        return reply
    return anthropic.Anthropic(api_key="sk-test", max_retries=0,
                               http_client=httpx2.Client(transport=httpx2.MockTransport(handler)))


def _reply(payload, stop="end_turn"):
    return httpx2.Response(200, json={
        "id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
        "content": [{"type": "text", "text": json.dumps(payload)}],
        "stop_reason": stop, "stop_sequence": None,
        "usage": {"input_tokens": 1, "output_tokens": 1},
    })


def test_request_shape_and_parse():
    seen = []
    reply = _reply({
            "is_receipt": True, "merchant": "NTUC FairPrice", "total": "23.45", "currency": "SGD",
            "date": "2026-10-31", "category": "Groceries", "payment_method": "card",
            "summary": "groceries", "confidence": "high", "problem": None,
    })
    r = ClaudeExtractor("claude-opus-5-5", "low", _client(reply, seen)).extract(b"\xff\xd8fake", ["Groceries"])
    assert r.merchant == "NTUC FairPrice" and str(r.total) == "23.45"
    req = seen[0]
    assert req.url.path == "/v1/messages"
    body = json.loads(req.content)
    assert body["model"] == "claude-opus-5-5"
    assert body["fallbacks"] == "default"
    assert "server-side-fallback-2026-07-01" in req.headers["anthropic-beta"]
    assert body["output_config"]["effort"] == "low"
    assert body["output_config"]["format"]["type"] == "json_schema"
    assert body["messages"][0]["content"][0]["source"]["media_type"] == "image/jpeg"
    assert "thinking" not in body


def test_refusal_raises():
    ex = ClaudeExtractor("claude-opus-5-5", "low", _client(_reply({}, stop="refusal"), []))
    with pytest.raises(ExtractionError, match="declined"):
        ex.extract(b"\xff\xd8", [])
