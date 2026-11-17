# Contributing to VBTSO

These rules apply to everyone, including the owner. They exist so that `main` is always in a working state and every change can be traced back to an issue, a decision and a review.

## Golden rules

1. **Nobody pushes to `main` directly.** Every change goes through a branch and a Pull Request (PR). `main` is protected on GitHub.
2. **Every PR closes an issue.** Open (or pick) an issue first, then write `Closes #<n>` in the PR description.
3. **Squash-merge only.** The PR title becomes the single commit on `main`, so the PR title must follow the commit convention below (CI checks it).
4. **Delete the branch after merge** (GitHub does it automatically).
5. **The plan is a living document.** If a PR changes a decision, it also updates [`docs/PROJECT.md`](docs/PROJECT.md), including a decision-log row.
6. **No secrets, no raw data, no weights in git.** Secrets go in `.env` (never committed; see `.env.example`). Data is versioned with DVC, and runs and weights are tracked in MLflow.
7. **Licence.** The project is AGPL-3.0 (see [`LICENSE`](LICENSE)). By contributing you agree that your contribution is released under it.

## Branch names

`<prefix>/<short-kebab-description>`, for example `feat/zone-counter`, `fix/split-leakage`, `exp/focal-loss`.

| Prefix | Use for |
|---|---|
| `feat/` | New functionality (code users or the pipeline will run) |
| `fix/` | Bug fix |
| `docs/` | Documentation and specs only |
| `exp/` | A training or evaluation experiment (one hypothesis per branch) |
| `data/` | Dataset changes: new sources, labels, DVC versions, pipeline stages |
| `refactor/` | Code change with no behaviour change |
| `test/` | Adding or fixing tests only |
| `ci/` | CI workflows and build tooling |
| `chore/` | Maintenance: dependencies, config, repo housekeeping |

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(optional scope): <summary in the imperative, lower case, no final dot>`.

Types are the branch prefixes without the slash: `feat`, `fix`, `docs`, `exp`, `data`, `refactor`, `test`, `ci`, `chore` (plus `perf`, `build`, `style`, `revert` when they fit).

Good examples:

```text
fix: keep training rows with missing engine size
feat(tracking): count vehicles crossing a zone line
exp(model): focal loss gamma=2 on rare classes
data: split Rabat frames by video
docs: add EDA findings to the project plan
chore: bump ultralytics to 8.4
```

Bad examples: `update`, `fixed stuff`, `WIP`, `Final version 2`.

Breaking change: add `!` after the type (`feat!: rename taxonomy classes`) and explain it in the body.

## Daily routine

```bash
git switch main
git pull                          # get the latest merged work
git switch -c feat/my-task        # new branch for today's task
# ... work, then commit often:
git add <files>
git commit -m "feat: ..."
git push -u origin feat/my-task   # first push of the branch; later just `git push`
# open the PR on GitHub (or: gh pr create --fill)
```

Before opening the PR:

```bash
just lint
just test
```

## Issues and milestones

- **Issues define problems.** Use the templates: *Bug*, *Feature*, *Experiment*.
- **Milestones group issues** into deliverables: D1 to D5 (see [`docs/PROJECT.md`](docs/PROJECT.md)). Optional work has the `stretch` label.
- Labels: one **type** label (`feat`, `fix`, `docs`, `exp`, `data`, `chore`) and one or more **area** labels (`data-eng`, `cv`, `mlops`, `infra`).
- An experiment issue states its hypothesis, dataset version, metric, MLflow run link and result, whether or not the result is positive.

## Pull requests

- Small and focused: one issue, one branch, one PR.
- Fill in the PR template (what, why, how it was tested).
- CI must be green before merging.
- If a decision changed, add the row to the decision log in `docs/PROJECT.md`.

## Development setup

See [`docs/DEVELOPER_GUIDE.md`](docs/DEVELOPER_GUIDE.md) for installing the tools and the full command cheat sheet.
