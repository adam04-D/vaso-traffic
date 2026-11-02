"""Edge entrypoint stub: `python -m vbtso.edge`.

Opens a video (file or RTSP stream), reads it, and posts one counts-only event to the API.
No detector yet: zones are empty. It exists to prove the container, the video path and the
edge-to-API wiring; milestone P3 replaces the body with detection, tracking and zone counting.

Configuration (environment variables, see .env.example):
  VIDEO_PATH       path to a video file (used if RTSP_URL is not set)
  RTSP_URL         camera stream; credentials stay in the environment, never in code
  API_URL          where to post events, e.g. http://api:8000/events (optional)
  CAMERA_ID        identifier put in the event (default: camera-1)
  WINDOW_SECONDS   window length written into the event (default: 30)
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
import urllib.request
from datetime import UTC, datetime

from vbtso.edge import build_event

log = logging.getLogger("vbtso.edge")


def _post(url: str, payload: dict) -> int:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    import cv2  # imported here so `build_event` stays importable without OpenCV

    source = os.environ.get("RTSP_URL") or os.environ.get("VIDEO_PATH")
    if not source:
        log.error("Set VIDEO_PATH or RTSP_URL")
        return 2

    capture = cv2.VideoCapture(source)
    if not capture.isOpened():
        log.error("Cannot open the video source (check the path or the stream URL)")
        return 2

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    declared_fps = capture.get(cv2.CAP_PROP_FPS)
    started = datetime.now(UTC)
    t0 = time.perf_counter()
    frames = 0
    while True:
        ok, _frame = capture.read()
        if not ok:
            break
        frames += 1
    capture.release()
    elapsed = max(time.perf_counter() - t0, 1e-9)
    log.info(
        "read %d frames, %dx%d, declared %.1f fps, decoded at %.1f fps",
        frames,
        width,
        height,
        declared_fps,
        frames / elapsed,
    )

    event = build_event(
        camera_id=os.environ.get("CAMERA_ID", "camera-1"),
        window_start=started,
        window_seconds=int(os.environ.get("WINDOW_SECONDS", "30")),
        fps=round(frames / elapsed, 2),
    )
    api_url = os.environ.get("API_URL")
    if api_url:
        log.info("POST %s -> %s", api_url, _post(api_url, event))
    else:
        log.info("no API_URL set, event not sent: %s", json.dumps(event))
    return 0


if __name__ == "__main__":
    sys.exit(main())
