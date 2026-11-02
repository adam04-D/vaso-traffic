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
    uv sync
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
