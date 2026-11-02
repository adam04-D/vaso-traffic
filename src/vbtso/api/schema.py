"""Counts-only event schema, version 1.0 (technical spec, section 7).

Privacy boundary: no images, no coordinates, no plate text. Every model forbids extra fields,
so a payload carrying anything beyond the agreed counts is rejected, not silently stored.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

SCHEMA_VERSION = "1.0"


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ZoneCounts(_Strict):
    zone_id: str = Field(min_length=1)
    crossings: dict[str, int] = Field(
        description="Vehicles that crossed the zone line in the window, by class name."
    )
    queue_vehicles: int = Field(ge=0, description="Vehicles queued in the approach zone.")


class Quality(_Strict):
    fps: float = Field(ge=0)
    mean_confidence: float = Field(ge=0, le=1)


class CountEvent(_Strict):
    schema_version: Literal["1.0"]
    camera_id: str = Field(min_length=1)
    window_start: datetime
    window_seconds: int = Field(gt=0)
    zones: list[ZoneCounts]
    quality: Quality
