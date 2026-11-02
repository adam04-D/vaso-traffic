# Developer guide

Setup and command cheat sheet for VBTSO. It grows with every milestone: each PR that adds a tool or a command also adds it here.

| Section | Added in |
|---|---|
| [1. Prerequisites](#1-prerequisites) | M0 |
| [2. Git workflow](#2-git-workflow) | M0 |
| [3. GitHub: issues, milestones, PRs](#3-github-issues-milestones-prs) | M0 |
| [4. Python environment (uv)](#4-python-environment-uv) | M1 |
| [5. Task runner (just)](#5-task-runner-just) | M1 |
| [6. Kaggle and Colab](#6-kaggle-and-colab) | M1 |
| [7. Quality: lint, tests, hooks, CI](#7-quality-lint-tests-hooks-ci) | M1 |
| [8. Data versioning (DVC)](#8-data-versioning-dvc) | M2 |
| 9. Docker images (edge, API) | M3 |

---

## 1. Prerequisites

| Tool | Why | macOS | Linux | Check |
|---|---|---|---|---|
| git | Version control | `xcode-select --install` | `sudo apt install git` | `git --version` |
| gh | GitHub CLI: PRs, issues, setup script | `brew install gh` | [cli.github.com](https://cli.github.com) | `gh --version` |
| uv | Python versions, venv, dependencies (replaces conda, pip, venv, pip-tools) | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` | same `curl` command | `uv --version` |
| just | Task runner (replaces ad-hoc shell commands and Makefiles) | `brew install just` | `uv tool install rust-just` or your package manager | `just --version` |
| Docker | Edge/API images, local S3 dev store | Docker Desktop or OrbStack | Docker Engine | `docker --version` |

No system Python is needed: uv downloads the pinned Python (3.12) itself. Do not use conda, Miniconda or a global `pip install` for this project.

First-time GitHub login:

```bash
gh auth login          # choose GitHub.com, HTTPS, login with browser
gh auth status
```

## 2. Git workflow

Full rules are in [`CONTRIBUTING.md`](../CONTRIBUTING.md). Summary: nobody pushes to `main`; every change is a branch and a PR; PRs are squash-merged; commit messages and PR titles follow Conventional Commits.

### Daily routine

```bash
git switch main
git pull                          # get the latest merged work
git switch -c feat/my-task        # new branch for today's task
# ... work, then commit often:
git add <files>
git commit -m "feat: ..."
git push -u origin feat/my-task   # first push of the branch; later just `git push`
gh pr create --fill               # or open the PR on GitHub
```

### Branch prefixes and commit types

| Branch | Commit type | Example commit |
|---|---|---|
| `feat/` | `feat` | `feat(tracking): count vehicles crossing a zone line` |
| `fix/` | `fix` | `fix: keep training rows with missing engine size` |
| `docs/` | `docs` | `docs: record T-013 licence decision` |
| `exp/` | `exp` | `exp(model): focal loss gamma=2 on rare classes` |
| `data/` | `data` | `data: add scene-level split v1` |
| `refactor/` | `refactor` | `refactor: move frame filters into vbtso.data` |
| `test/` | `test` | `test: cover zone polygon edge cases` |
| `ci/` | `ci` | `ci: build edge image on pull requests` |
| `chore/` | `chore` | `chore: bump ultralytics to 8.4` |

### Useful git commands

```bash
git status                        # what changed
git diff                          # unstaged changes
git diff --staged                 # what will be committed
git log --oneline --graph -15     # recent history
git switch <branch>               # change branch
git branch -d <branch>            # delete a merged local branch
git fetch --prune                 # forget remote branches deleted after merge
git restore <file>                # discard local changes to a file
git restore --staged <file>       # unstage a file
git commit --amend                # fix the last commit (only before pushing)
git stash / git stash pop         # park work temporarily
git rebase main                   # update your branch with main (before pushing)
```

After a PR is merged:

```bash
git switch main
git pull
git branch -d feat/my-task
git fetch --prune
```

## 3. GitHub: issues, milestones, PRs

One-time setup (labels, milestones, starter issues, `main` protection): run `bash scripts/github_setup.sh` once, after `gh auth login`.

```bash
gh issue list                               # open issues
gh issue list --milestone "M1 Environment"  # issues of one milestone
gh issue view 12                            # read an issue
gh issue create                             # new issue (pick a template)
gh issue develop 12 --name feat/zone-counter --checkout   # branch linked to issue #12

gh pr create --fill --milestone "M1 Environment"   # open a PR from the current branch
gh pr status                                # your PRs and their checks
gh pr checks                                # CI status of the current PR
gh pr view --web                            # open the PR in the browser
gh pr merge --squash --delete-branch        # merge when CI is green
```

In the PR description, write `Closes #12` so the issue closes when the PR is merged.

## 4. Python environment (uv)

uv replaces conda, Miniconda, pip, venv and requirements files. `pyproject.toml` declares dependencies; `uv.lock` pins exact versions and is committed.

First time on a new machine:

```bash
git clone https://github.com/adam04-D/vaso-traffic.git && cd vaso-traffic
just setup            # Python 3.12 + .venv + all extras + dev tools + git hooks (downloads PyTorch, a few GB)
# or, to work on docs/specs/lint/tests only:
just setup-light
```

Dependency layout:

| Where | What | Install |
|---|---|---|
| core | numpy, pyyaml | always |
| extra `train` | ultralytics, torch, torchvision, opencv, pandas, pillow, imagehash, matplotlib, roboflow | `uv sync --extra train` |
| extra `edge` | onnxruntime, opencv | `uv sync --extra edge` |
| extra `api` | fastapi, uvicorn, pydantic | `uv sync --extra api` |
| group `dev` | ruff, pytest, pre-commit, nbstripout, dvc, jupyterlab | installed by default by `uv sync` |

Everyday commands:

```bash
uv sync                          # make .venv match uv.lock (dev group only)
uv sync --all-extras             # everything
uv run <command>                 # run inside the project env, e.g. uv run python -m vbtso
uv run pytest tests/test_smoke.py
uv add numpy                     # add a core dependency (edits pyproject.toml and uv.lock)
uv add --optional train kornia   # add a dependency to the `train` extra
uv add --dev pytest-xdist        # add a developer tool to the dev group
uv remove <package>
uv lock --upgrade-package ultralytics   # upgrade one package (or: just upgrade ultralytics)
uv tree                          # dependency tree
uv python list                   # available Python versions
uv python install 3.12           # install Python 3.12 (uv does this automatically)
```

Rules: never `pip install` into the project env, never edit `uv.lock` by hand, and commit `pyproject.toml` and `uv.lock` together in the same PR.

Jupyter: `just lab`, or in VS Code select the `.venv` interpreter.

## 5. Task runner (just)

`just` with no arguments lists all recipes.

| Recipe | What it does |
|---|---|
| `just setup` | First-time setup, all extras and git hooks |
| `just setup-light` | Dev tools only, no PyTorch |
| `just lint` | `ruff check` and `ruff format --check` (no changes made) |
| `just fmt` | Auto-fix lint issues and format |
| `just test` | pytest; extra arguments pass through, e.g. `just test -k smoke` |
| `just check` | lint + test, what CI runs |
| `just hooks` | Run all pre-commit hooks on all files |
| `just nb-clean` | Strip outputs from all notebooks |
| `just lab` | JupyterLab in the project env |
| `just lock` | Regenerate `uv.lock` |
| `just upgrade <pkg>` | Upgrade one dependency |
| `just clean` | Remove caches and build artefacts |

Recipes for DVC and Docker are added in milestones M2 and M3.

## 6. Kaggle and Colab

Training GPUs run outside the Mac, so the same code is installed from the repo:

```bash
pip install -q uv
git clone https://github.com/adam04-D/vaso-traffic.git && cd vaso-traffic
uv pip install --system ".[train]"     # the platform's own PyTorch is reused when it satisfies the pin
```

Secrets (R2 keys, `HF_TOKEN`, `ROBOFLOW_API_KEY`) go in Kaggle Secrets or Colab Secrets and are exported as environment variables, never written into a notebook. Data comes from DVC (milestone M2), not from Google Drive.

## 7. Quality: lint, tests, hooks, CI

- **ruff** lints and formats (line length 100). The legacy notebooks in `notebooks/` and `main.ipynb` are excluded until they are ported in P1.
- **pytest** runs the tests in `tests/`.
- **pre-commit** runs on every commit: YAML/TOML checks, end-of-file and whitespace fixes, large-file guard (1 MB), ruff, and **nbstripout**, which removes notebook outputs. The first commit that touches an old notebook will therefore change it; the old results are recorded in `docs/legacy_results.md`.
- **CI** (`.github/workflows/ci.yml`) runs on every PR: PR-title check (Conventional Commits, types `feat fix docs exp data refactor test ci chore perf build style revert`) and `ruff` + `pytest` with `uv sync --frozen`.

```bash
just check                        # before pushing
just hooks                        # run hooks on every file
uv run pre-commit autoupdate      # bump hook versions (its own chore PR)
```

After the first CI run, add the two checks (`Lint and test`, `PR title (Conventional Commits)`) as required status checks in the `protect-main` ruleset: GitHub, Settings, Rules, Rulesets.

## 8. Data versioning (DVC)

Git stores code and small pointer files (`*.dvc`, `dvc.lock`). The data itself lives in object storage, and DVC moves it. Google Drive is no longer used.

| Remote | Where | Used for |
|---|---|---|
| `r2` (default) | Cloudflare R2 bucket, S3 protocol | Shared store: Mac, Kaggle, Colab, any other machine |
| `local` | S3-compatible dev store (Adobe S3Mock) in Docker on `localhost:9090` | Offline development and tests, no cloud account needed |

### One-time repository setup (done once, by the owner)

```bash
uv run dvc init
uv run dvc remote add -d r2 s3://vbtso-data/dvc
uv run dvc remote add local s3://vbtso-data/dvc
uv run dvc remote modify local endpointurl http://localhost:9090
# git add .dvc .dvcignore && commit, in the PR
```

### One-time setup per machine

1. Copy `.env.example` to `.env` and fill it in (`.env` is git-ignored).
2. R2 credentials: Cloudflare dashboard, R2, Manage API tokens, create a token with Object Read & Write on the bucket. Put the key pair in `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and the account endpoint in `AWS_ENDPOINT_URL`.
   If DVC ignores `AWS_ENDPOINT_URL`, set the endpoint locally instead: `uv run dvc remote modify --local r2 endpointurl https://<account-id>.r2.cloudflarestorage.com`.
3. Local dev store (optional): `just up`, then once `just dvc-local-setup` (it stores placeholder credentials in the git-ignored `.dvc/config.local`; the store accepts any).

### Everyday commands

```bash
uv run dvc add data/raw/rabat_day.mp4   # track a file or folder; creates data/raw/rabat_day.mp4.dvc
git add data/raw/rabat_day.mp4.dvc data/raw/.gitignore   # commit the pointer, not the data
just dvc-push                           # upload to r2   (just dvc-push local  for the local store)
just dvc-pull                           # download what the current commit points to
just dvc-status                         # what differs from the remote
uv run dvc repro                        # run the pipeline in dvc.yaml (added in P1), skipping unchanged stages
uv run dvc dag                          # draw the pipeline graph
uv run dvc remote list
```

Switching dataset version = switching git commit or tag, then `dvc pull`. Never commit data, weights or `.env`.

### Local services

```bash
just up      # starts the local S3 store and creates the bucket
just down    # stops it (data stays in the Docker volume)
docker compose down -v   # stops it and erases its data
just logs
```

The local store is Adobe S3Mock: it accepts any credentials and is for development and tests only, never for real data. MinIO was the first choice but its container images are no longer pullable from the public registries. Pin the image tag in `.env` (`S3MOCK_IMAGE`) after the first successful `just up` (`docker compose images` shows what was pulled).

### Kaggle / Colab

```python
import os
from kaggle_secrets import UserSecretsClient  # Colab: from google.colab import userdata

s = UserSecretsClient()
for k in ["AWS_ENDPOINT_URL", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]:
    os.environ[k] = s.get_secret(k)
```

then `!dvc pull -r r2` after the install step of section 6 (add `dvc[s3]` with `uv pip install --system "dvc[s3]"`).
