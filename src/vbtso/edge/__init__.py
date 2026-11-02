"""Edge runtime (placeholder until milestone P3): video in, counts-only events out.

`build_event` is pure and dependency-free, so it is tested without OpenCV. It produces a
payload matching `vbtso.api.schema.CountEvent`.
"""

from __future__ import annotations

from datetime import UTC, datetime

SCHEMA_VERSION = "1.0"


def build_event(
    camera_id: str,
    window_start: datetime,
    window_seconds: int,
    zones: list[dict] | None = None,
    fps: float = 0.0,
    mean_confidence: float = 0.0,
) -> dict:
    """Build a schema v1.0 counts-only event as a JSON-serialisable dict."""
    if window_start.tzinfo is None:
        window_start = window_start.replace(tzinfo=UTC)
    return {
        "schema_version": SCHEMA_VERSION,
        "camera_id": camera_id,
        "window_start": window_start.isoformat(),
        "window_seconds": window_seconds,
        "zones": zones or [],
        "quality": {"fps": fps, "mean_confidence": mean_confidence},
    }
