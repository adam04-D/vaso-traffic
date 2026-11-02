from datetime import datetime

import pytest

pytest.importorskip("fastapi")
pytest.importorskip("httpx")

from fastapi.testclient import TestClient

from vbtso.api.main import app
from vbtso.edge import build_event

client = TestClient(app)


def valid_event() -> dict:
    return build_event(
        camera_id="cam-1",
        window_start=datetime(2026, 11, 2, 10, 0),
        window_seconds=30,
        zones=[
            {
                "zone_id": "north_approach",
                "crossings": {"car": 12, "bus": 1},
                "queue_vehicles": 4,
            }
        ],
        fps=14.2,
        mean_confidence=0.71,
    )


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["schema_version"] == "1.0"


def test_accepts_valid_event():
    response = client.post("/events", json=valid_event())
    assert response.status_code == 202
    assert response.json()["status"] == "accepted"


def test_rejects_extra_field():
    """Privacy boundary: nothing beyond the agreed counts may be sent."""
    payload = valid_event()
    payload["image_base64"] = "AAAA"
    assert client.post("/events", json=payload).status_code == 422


def test_rejects_wrong_schema_version():
    payload = valid_event()
    payload["schema_version"] = "2.0"
    assert client.post("/events", json=payload).status_code == 422


def test_rejects_negative_queue():
    payload = valid_event()
    payload["zones"][0]["queue_vehicles"] = -1
    assert client.post("/events", json=payload).status_code == 422
