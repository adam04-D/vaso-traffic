# Edge runtime image: video in, counts-only events out. Build from the repo root:
#   docker build -f docker/edge.Dockerfile -t vbtso-edge .
# Only the `edge` extra is installed (onnxruntime + OpenCV headless), no PyTorch.
# Base images are pinned to exact versions on purpose: bump them in a dedicated chore PR.
ARG PYTHON_VERSION=3.12.12
ARG UV_VERSION=0.13.5

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# ---- build stage ----
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder
COPY --from=uv /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app

COPY pyproject.toml uv.lock README.md LICENSE ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project --extra edge

COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable --extra edge

# ---- runtime stage ----
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime
# OpenCV (headless) needs the GLib runtime library
RUN apt-get update \
    && apt-get install -y --no-install-recommends libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --create-home --home-dir /home/vbtso vbtso
COPY --from=builder --chown=vbtso:vbtso /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER vbtso
# The edge process is a batch/stream worker with no HTTP port, so there is no HEALTHCHECK.
# Configuration (see .env.example): VIDEO_PATH or RTSP_URL, API_URL, CAMERA_ID, WINDOW_SECONDS.
ENTRYPOINT ["python", "-m", "vbtso.edge"]
