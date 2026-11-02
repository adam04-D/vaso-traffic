# Event-ingestion API image. Build from the repo root:
#   docker build -f docker/api.Dockerfile -t vbtso-api .
# Base images are pinned to exact versions on purpose: bump them in a dedicated chore PR.
ARG PYTHON_VERSION=3.12.12
ARG UV_VERSION=0.13.5

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# ---- build stage: resolve and install the locked dependencies into a virtualenv ----
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder
COPY --from=uv /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app

# 1) dependencies only (cached until pyproject.toml or uv.lock change)
COPY pyproject.toml uv.lock README.md LICENSE ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project --extra api

# 2) the project itself, installed as a normal (non-editable) package
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable --extra api

# ---- runtime stage: slim image, no build tools, non-root user ----
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime
RUN useradd --system --uid 10001 --create-home --home-dir /home/vbtso vbtso
COPY --from=builder --chown=vbtso:vbtso /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER vbtso
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]
CMD ["uvicorn", "vbtso.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
