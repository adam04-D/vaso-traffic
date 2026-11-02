from datetime import UTC, datetime

from vbtso.edge import build_event


def test_build_event_shape():
    event = build_event("cam-1", datetime(2026, 11, 2, 10, 0, tzinfo=UTC), 30, fps=12.5)
    assert event["schema_version"] == "1.0"
    assert event["camera_id"] == "cam-1"
    assert event["window_seconds"] == 30
    assert event["zones"] == []
    assert event["quality"] == {"fps": 12.5, "mean_confidence": 0.0}


def test_naive_datetime_gets_utc():
    event = build_event("cam-1", datetime(2026, 11, 2, 10, 0), 30)
    assert event["window_start"].endswith("+00:00")
