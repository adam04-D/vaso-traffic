"""Event-ingestion service (placeholder until milestone P5).

Today it validates events against schema v1 and acknowledges them. Storage and the
signal-timing advisor come later; keeping only the last events in memory is enough to prove
the edge-to-API wiring.
"""

from __future__ import annotations

import logging
from collections import deque

from fastapi import FastAPI

from vbtso import __version__
from vbtso.api.schema import SCHEMA_VERSION, CountEvent

log = logging.getLogger("vbtso.api")

app = FastAPI(title="VBTSO event API", version=__version__)

# Placeholder store: the most recent events, lost on restart
_recent: deque[CountEvent] = deque(maxlen=100)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": __version__, "schema_version": SCHEMA_VERSION}


@app.post("/events", status_code=202)
def ingest(event: CountEvent) -> dict[str, int | str]:
    _recent.append(event)
    log.info("event camera=%s zones=%d", event.camera_id, len(event.zones))
    return {"status": "accepted", "stored": len(_recent)}
