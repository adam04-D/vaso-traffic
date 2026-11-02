# Developer guide

Setup and command cheat sheet for VBTSO. It grows with every milestone: each PR that adds a tool or a command also adds it here.

| Section | Added in |
|---|---|
| [1. Prerequisites](#1-prerequisites) | M0 |
| [2. Git workflow](#2-git-workflow) | M0 |
| [3. GitHub: issues, milestones, PRs](#3-github-issues-milestones-prs) | M0 |
| 4. Python environment (uv) | M1 |
| 5. Task runner (just) | M1 |
| 6. Data versioning (DVC) | M2 |
| 7. Docker and compose | M3 |

---

## 1. Prerequisites

| Tool | Why | macOS | Linux | Check |
|---|---|---|---|---|
| git | Version control | `xcode-select --install` | `sudo apt install git` | `git --version` |
| gh | GitHub CLI: PRs, issues, setup script | `brew install gh` | [cli.github.com](https://cli.github.com) | `gh --version` |
| uv | Python versions, venv, dependencies (replaces conda, pip, venv, pip-tools) | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` | same `curl` command | `uv --version` |
| just | Task runner (replaces ad-hoc shell commands and Makefiles) | `brew install just` | `uv tool install rust-just` or your package manager | `just --version` |
| Docker | Edge/API images, local MinIO | Docker Desktop or OrbStack | Docker Engine | `docker --version` |

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
