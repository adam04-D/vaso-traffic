# VBTSO task runner. `just` lists the recipes; `just <recipe>` runs one.
# Everything runs through uv, so no manual venv activation is needed.

set dotenv-load := true

# List available recipes
default:
    @just --list

# First-time setup: Python 3.12, virtualenv, all extras, dev tools, git hooks
setup:
    uv sync --all-extras
    uv run pre-commit install --install-hooks
    @echo "Done. Try: just check"

# Lightweight setup (dev tools only, no PyTorch): enough for lint, tests and docs
setup-light:
    uv sync --extra api
    uv run pre-commit install --install-hooks

# Lint without changing files
lint:
    uv run ruff check .
    uv run ruff format --check .

# Auto-fix lint issues and format the code
fmt:
    uv run ruff check --fix .
    uv run ruff format .

# Run the tests
test *args:
    uv run pytest {{args}}

# What CI runs: lint + tests
check: lint test

# Run every pre-commit hook on every file
hooks:
    uv run pre-commit run --all-files

# Strip outputs from all notebooks (keeps diffs small)
nb-clean:
    uv run nbstripout notebooks/*.ipynb main.ipynb

# Open JupyterLab in the project environment
lab:
    uv run jupyter lab

# Start local services: S3-compatible dev store (localhost:9090) and the event API (localhost:8000)
up:
    docker compose up -d --wait s3mock api

# Build the API and edge images
build:
    docker compose --profile edge build

# Run the edge worker on a video (default data/samples/clip.mp4) and post one event to the API
edge video="/data/samples/clip.mp4":
    VIDEO_PATH={{video}} docker compose --profile edge run --rm edge

# Stop local services (data is kept in the Docker volume; `docker compose down -v` erases it)
down:
    docker compose down

# Follow the logs of the local services
logs:
    docker compose logs -f

# One-time per machine: give the DVC `local` remote placeholder credentials (the dev store accepts any; kept in .dvc/config.local, not in git)
dvc-local-setup:
    uv run dvc remote modify --local local access_key_id local
    uv run dvc remote modify --local local secret_access_key local

# Show which tracked data differs from the cache and from a remote (default: r2)
dvc-status remote="r2":
    uv run dvc status --cloud -r {{remote}}

# Download tracked data from a remote (default: r2)
dvc-pull remote="r2":
    uv run dvc pull -r {{remote}}

# Upload tracked data to a remote (default: r2)
dvc-push remote="r2":
    uv run dvc push -r {{remote}}

# Regenerate uv.lock after editing pyproject.toml
lock:
    uv lock

# Upgrade one dependency in the lock file, e.g. `just upgrade ultralytics`
upgrade package:
    uv lock --upgrade-package {{package}}
    uv sync --all-extras

# Remove caches and build artefacts (keeps .venv)
clean:
    rm -rf .ruff_cache .pytest_cache .coverage dist build
    find . -name __pycache__ -type d -prune -not -path "./.venv/*" -exec rm -rf {} +
