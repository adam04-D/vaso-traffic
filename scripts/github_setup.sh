#!/usr/bin/env bash
# One-time GitHub setup for VBTSO: repo settings, labels, milestones, issues, main protection.
# Run it yourself, from the repo root, after `gh auth login`:
#   bash scripts/github_setup.sh
# Safe to re-run: labels are upserted (--force), and milestones and issues that already exist
# (same title) are skipped. Every call is retried up to 4 times on network errors.
set -uo pipefail

REPO="${REPO:-adam04-D/vaso-traffic}"
echo "Configuring $REPO"

# retry <cmd...>: run a command up to 4 times, waiting 3 s, 6 s, 9 s between attempts
retry() {
  local n
  for n in 1 2 3 4; do
    "$@" && return 0
    [ "$n" -lt 4 ] && { echo "  retry $n/3 in $((n*3)) s..." >&2; sleep $((n*3)); }
  done
  return 1
}

# Existing milestone and issue titles, so a re-run never creates duplicates
# (if GitHub cannot be reached here, stop: creating issues blind could duplicate them)
EXISTING_MILESTONES="$(retry gh api "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title')" \
  || { echo "Cannot reach GitHub, nothing changed. Check your network and re-run." >&2; exit 1; }
EXISTING_ISSUES="$(retry gh issue list --repo "$REPO" --state all --limit 500 --json title --jq '.[].title')" \
  || { echo "Cannot reach GitHub, nothing changed. Check your network and re-run." >&2; exit 1; }
has() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

# ---------------------------------------------------------------------------
# 1. Repository settings: squash-merge only, auto-delete merged branches
# ---------------------------------------------------------------------------
# (via the REST API: `gh repo edit` has no flag to disable merge commits)
retry gh api "repos/$REPO" --method PATCH \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  --jq '"settings: squash=\(.allow_squash_merge) merge=\(.allow_merge_commit) rebase=\(.allow_rebase_merge) delete_branch=\(.delete_branch_on_merge)"' \
  || echo "SETTINGS FAILED"

# ---------------------------------------------------------------------------
# 2. Labels: type (one per issue) + area (one or more)
# ---------------------------------------------------------------------------
label() { retry gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force; }

label feat     0E8A16 "New functionality"
label fix      D73A4A "Bug fix"
label docs     0075CA "Documentation and specs"
label exp      8250DF "Training / evaluation experiment"
label data     FBCA04 "Dataset, labels, DVC, data pipeline"
label chore    C5DEF5 "Maintenance, tooling, dependencies"
label data-eng BFD4F2 "Area: data engineering"
label cv       F9D0C4 "Area: computer vision models"
label mlops    D4C5F9 "Area: tracking, registry, CI for models"
label control  C2E0C6 "Area: signal control and simulation"
label infra    EDEDED "Area: environment, CI, Docker"

# ---------------------------------------------------------------------------
# 3. Milestones
# ---------------------------------------------------------------------------
milestone() {
  if has "$EXISTING_MILESTONES" "$1"; then echo "milestone exists: $1"; return; fi
  retry gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null \
    && echo "milestone: $1" || echo "MILESTONE FAILED: $1"
}

milestone "M0 Governance"      "AGPL licence, contribution rules, templates, GitHub setup, developer guide v1"
milestone "M1 Environment"     "uv + just + pre-commit, pyproject, package skeleton, CI"
milestone "M2 Data platform"   "DVC with Cloudflare R2 (shared) and MinIO (local) remotes"
milestone "M3 Containers"      "Edge and API Docker images, compose, CI image builds"
milestone "P1 Data pipeline"   "Sourcing, filtering, scene-level split, versioned dataset"
milestone "P2 Detector"        "Baseline detector, per-class metrics, imbalance and ablation experiments"
milestone "P3 Tracking"        "Tracking and zone counting, count error vs manual counts"
milestone "P4 Control"         "SUMO scenario, controllers C0 to C2, optional RL"
milestone "P5 Edge and API"    "Export benchmarks, FastAPI event service, schema v1"
milestone "R Deep review"      "Full review of data, CV, MLOps, AI eng, architecture, algorithms"

# ---------------------------------------------------------------------------
# 4. Issues  (title | labels | milestone | body)
# ---------------------------------------------------------------------------
issue() {
  if has "$EXISTING_ISSUES" "$1"; then echo "issue exists: $1"; return; fi
  retry gh issue create --repo "$REPO" --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null \
    && echo "issue: $1" || echo "ISSUE FAILED: $1"
}

# M0
issue "chore: add AGPL licence, contribution rules and templates" "chore,infra" "M0 Governance" \
"LICENSE (AGPL-3.0), CONTRIBUTING.md, PR and issue templates, scripts/github_setup.sh, docs/DEVELOPER_GUIDE.md v1, spec rows T-013/T-014. See plan M0."
issue "chore: protect main and configure merge settings" "chore,infra" "M0 Governance" \
"Run scripts/github_setup.sh. Acceptance: a direct push to main is refused; only squash-merge is offered."

# M1
issue "chore: set up uv, just and pre-commit with a src/vbtso package" "chore,infra" "M1 Environment" \
"pyproject.toml with extras train/edge/api and a dev group, .python-version 3.12, uv.lock, justfile, pre-commit, .env.example, package skeleton, smoke test. Remove requirements.txt."
issue "ci: lint, test and PR-title check on every pull request" "chore,infra,mlops" "M1 Environment" \
"GitHub Actions with setup-uv: ruff, pytest, semantic PR title (types incl. exp, data). Then add the CI checks as required in the main ruleset."

# M2
issue "chore: create Cloudflare R2 bucket and access keys" "chore,data-eng" "M2 Data platform" \
"Bucket for DVC, scoped API token, keys stored in .env locally and as Kaggle/Colab secrets. Never committed."
issue "data: initialise DVC with r2 and local MinIO remotes" "data,data-eng" "M2 Data platform" \
"dvc init, remotes r2 (default) and local (MinIO in docker compose), stub dvc.yaml stages extract/filter/split. Acceptance: push/pull round-trip on both remotes, pull from Kaggle."

# M3
issue "ci: edge and API Docker images with compose" "chore,infra" "M3 Containers" \
"Multi-stage uv-based images, non-root, health checks; compose services api, edge, minio. Acceptance: /health answers, edge processes a sample clip."
issue "ci: build Docker images on every pull request" "chore,infra" "M3 Containers" \
"Build both images in CI without pushing."

# P1
issue "data: find fixed-camera footage for Rabat" "data,data-eng" "P1 Data pipeline" \
"Public webcams, own recordings or partners. Record licence and privacy terms. Blocks the domain-match plan (functional open question 4)."
issue "data: verify licences of public datasets" "data,data-eng" "P1 Data pipeline" \
"UA-DETRAC, VisDrone, BDD100K, Roboflow Universe sets: redistribution and commercial terms, from official sources (technical 2.3)."
issue "data: frame extraction, quality filters and scene-level split as DVC stages" "data,data-eng" "P1 Data pipeline" \
"Port notebook 01 logic into src/vbtso/data, run as dvc.yaml stages, split by scene not frame (T-002)."

# P2
issue "feat: baseline detector training with per-class metrics" "feat,cv" "P2 Detector" \
"YOLO26n vs YOLO11n on the scene-level split, per-class mAP50 with rare classes reported separately (technical 3.2)."
issue "exp: X3 focal and class-balanced losses on rare classes" "exp,cv" "P2 Detector" "Technical section 9, X3."
issue "exp: X4 ablations over resolution, augmentation and model size" "exp,cv" "P2 Detector" "Technical section 9, X4."
issue "exp: X1 mini anchor-free detector in PyTorch" "exp,cv" "P2 Detector" "Technical section 9, X1."
issue "exp: X6 domain shift and X7 zero-shot baseline" "exp,cv" "P2 Detector" "Technical section 9, X6 and X7."
issue "exp: X8 rare-class label QA with an offline VLM" "exp,cv,data-eng" "P2 Detector" "Technical section 9, X8. The VLM never writes labels."

# P3
issue "feat: tracking and zone counting from a recorded video" "feat,cv" "P3 Tracking" \
"Tracker + per-camera zone config, crossings and queue per approach. Acceptance: count MAPE vs manual count on held-out clips (functional T2)."
issue "exp: X2 Kalman + Hungarian tracker vs ByteTrack-style" "exp,cv" "P3 Tracking" "Technical section 9, X2."

# P4
issue "feat: SUMO scenario with fixed-time, Webster and max-pressure" "feat,control" "P4 Control" \
"One intersection, several demand levels and seeds, ideal vs noisy sensing (technical 6.2)."
issue "exp: X5 RL controller vs max-pressure" "exp,control" "P4 Control" "Technical section 9, X5. Only after C2 works."

# P5
issue "feat: export benchmarks (ONNX, OpenVINO, NCNN)" "feat,cv,mlops" "P5 Edge and API" \
"Measured FPS, latency and accuracy drop per format on available hardware (technical 5.3)."
issue "feat: FastAPI event service with schema v1" "feat,infra" "P5 Edge and API" \
"Validate and store counts-only events (technical 7). Decide n8n vs FastAPI (T-007)."

# R
issue "docs: deep review of the project" "docs" "R Deep review" \
"Review idea and scope, data engineering, CV, MLOps, AI engineering, architecture and production readiness, optimisation algorithms, methodology. Settle T-006 (MLflow vs W&B) and T-007. Update specs and refine P1-P5 issues."

# ---------------------------------------------------------------------------
# 5. Protect main with a ruleset: PR required, no force-push, no deletion.
#    Needs a public repo, or GitHub Pro/Team for a private one.
#    Required CI checks are added after M1, once the CI job names exist
#    (adding them now would block every merge).
#    required_approving_review_count is 0 because a solo owner cannot approve their own PR.
# ---------------------------------------------------------------------------
if retry gh api "repos/$REPO/rulesets" --jq '.[].name' | grep -Fxq protect-main; then
  echo "ruleset exists: protect-main"
else
gh api "repos/$REPO/rulesets" --method POST --input - <<'JSON' && echo "ruleset: protect-main"
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    }
  ]
}
JSON
fi

echo "Done. Re-run this script if any line above says FAILED."
