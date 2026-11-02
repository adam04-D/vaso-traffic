#!/usr/bin/env bash
# Apply reviews R1, R3 to R7 to milestones P2 to P5: update, label and create issues.
# Run it yourself from the repo root:  bash scripts/gh_issues_review.sh
# Safe to re-run: existing titles are skipped, and every call is retried on network errors.
set -uo pipefail

REPO="${REPO:-adam04-D/vaso-traffic}"

retry() {
  local n
  for n in 1 2 3 4; do
    "$@" && return 0
    [ "$n" -lt 4 ] && { echo "  retry $n/3 in $((n*3)) s..." >&2; sleep $((n*3)); }
  done
  return 1
}

ISSUES_JSON="$(retry gh issue list --repo "$REPO" --state all --limit 500 --json number,title)" \
  || { echo "Cannot reach GitHub, nothing changed. Re-run later." >&2; exit 1; }
number_of() { printf '%s' "$ISSUES_JSON" | python3 -c "import json,sys; t=sys.argv[1]; print(next((str(i['number']) for i in json.load(sys.stdin) if i['title']==t), ''))" "$1"; }

issue() {
  if [ -n "$(number_of "$1")" ]; then echo "issue exists: $1"; return; fi
  retry gh issue create --repo "$REPO" --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null \
    && echo "issue: $1" || echo "ISSUE FAILED: $1"
}

# edit_issue <current title> <new title or ""> <new body>
edit_issue() {
  local n; n="$(number_of "$1")"
  if [ -z "$n" ]; then n="$(number_of "$2")"; fi
  if [ -z "$n" ]; then echo "not found: $1"; return; fi
  if [ -n "$2" ]; then
    retry gh issue edit "$n" --repo "$REPO" --title "$2" --body "$3" >/dev/null && echo "edited #$n"
  else
    retry gh issue edit "$n" --repo "$REPO" --body "$3" >/dev/null && echo "edited #$n"
  fi
}

add_label() {
  local n; n="$(number_of "$1")"
  [ -z "$n" ] && { echo "not found: $1"; return; }
  retry gh issue edit "$n" --repo "$REPO" --add-label "$2" >/dev/null && echo "labelled #$n $2"
}

# ---- labels ----
retry gh label create stretch --repo "$REPO" --color 5319E7 --description "After v1.0 (review R1)" --force >/dev/null && echo "label: stretch"

# ---- existing issues: update to the review decisions ----
edit_issue "feat: baseline detector training with per-class metrics" "" \
"YOLO26n trained COCO -> BMD-45 -> Rabat (fine-tune videos). Per-class AP50 and AP50-95 with box counts, per condition (day/night/rain), on the held-out Rabat video and BMD-45 val. 3 seeds for published numbers. Uses cls_remap and cls_pw. Technical 3.2, T-024; review R3."

edit_issue "feat: export benchmarks (ONNX, OpenVINO, NCNN)" "feat: export benchmarks on the Mac (ONNX, Core ML, INT8)" \
"PyTorch-MPS (reference), ONNX Runtime CPU (deployment format), Core ML (optional), ONNX INT8. Per format: Rabat-test mAP drop, latency p50/p95, FPS, size. OpenVINO/TensorRT/NCNN out until hardware exists. Technical 5.3, T-026; review R5."

edit_issue "feat: FastAPI event service with schema v1" "" \
"/v1/events and /v1/advice, /health, /metrics. SQLite behind a repository layer, idempotent on (camera_id, window_start). Per-camera bearer token. pydantic-settings. Structured JSON logs. n8n dropped (T-007). Technical 7, T-027; review R6."

edit_issue "feat: SUMO scenario with fixed-time, Webster and max-pressure" "" \
"Run C0 (Webster-tuned fixed-time), C1, C2 in SUMO: RESCO single-intersection sanity check first, then the Rabat junction. 4 demand scenarios, 10 seeds, mean and 95% CI, warm-up discarded. Technical 6.2, T-028; review R7."

add_label "exp: X1 mini anchor-free detector in PyTorch" stretch
add_label "exp: X5 RL controller vs max-pressure" stretch

# ---- P2 Detector ----
MS="P2 Detector"
issue "chore: MLflow on DagsHub for tracking and model registry" "chore,mlops" "$MS" \
"Connect the repo to DagsHub, enable Ultralytics' MLflow integration, document secrets for Kaggle/Colab (MLFLOW_TRACKING_URI/USERNAME/PASSWORD). Acceptance: a run from Kaggle appears with params, metrics and artefacts. T-025."
issue "feat: training entry point with configs and run metadata" "feat,mlops,cv" "$MS" \
"python -m vbtso.models.train --config configs/train/<name>.yaml. Logs config, git commit, DVC dataset hash, uv.lock hash, seed, hardware, per-class metrics, confusion matrix. Kaggle/Colab notebooks become thin runners. T-025."
issue "exp: RF-DETR Nano vs YOLO26n on the same splits" "exp,cv" "$MS" \
"Same transfer chain and splits; compare per-class AP and latency (Mac ONNX). RF-DETR Nano is Apache-2.0 (licence escape hatch, technical 3.4). Vendor COCO numbers to be reproduced, not quoted. T-024."
issue "feat: model gate script for promotion" "feat,mlops" "$MS" \
"Compare a candidate with the registered model on the fixed Rabat test and BMD-45 val; promote only if no core class is worse beyond a tolerance. Promotion is logged in the MLflow registry. T-025."
issue "ci: manual CPU smoke-training workflow" "chore,mlops,infra" "$MS" \
"workflow_dispatch (or nightly): 1 epoch on the fixture, ONNX export, edge stub on a clip. Not per PR (PyTorch is slow in CI). T-025."
issue "feat: evaluation report per class and condition" "feat,cv" "$MS" \
"Per-class AP with box counts, confusion matrix, day/night/rain slices, hard cases (three-wheeler vs motorcycle, grand taxi vs car). Rare classes separate, never averaged. Markdown/HTML report logged to MLflow. Review R3."

# ---- P3 Tracking ----
MS="P3 Tracking"
issue "feat: count MAPE evaluation against manual CVAT counts" "feat,cv" "$MS" \
"Manual counts per line per 5-min window on fixed-camera clips (MoVITS if fixed, else UA-DETRAC once licensed). Metric: count MAPE (target <= 10%). HOTA/IDF1 via TrackEval where ground-truth tracks exist. T-024."
issue "feat: ONNX Runtime edge inference without PyTorch" "feat,cv,infra" "$MS" \
"Own letterbox/normalisation and output decoding for the NMS-free YOLO26 ONNX output; standalone tracker; runs in the edge image. Benchmarked against Ultralytics inference for parity. T-026."

# ---- P4 Control ----
MS="P4 Control"
issue "feat: controllers C0 to C2 as pure functions with safety constraints" "feat,control" "$MS" \
"Webster-tuned fixed-time, adaptive Webster/queue-proportional, max-pressure (camera-only variant = largest weighted queue). Min/max green, amber, all-red, pedestrian minimum shared by all. Unit tests without SUMO. T-028."
issue "feat: SUMO TraCI adapter and RESCO sanity check" "feat,control" "$MS" \
"Thin adapter between vbtso.control and SUMO (TraCI or libsumo). Reproduce RESCO single-intersection fixed-time/greedy/max-pressure orderings with sumo-rl (MIT) networks before using our own. T-028."
issue "data: propose a Rabat junction from OpenStreetMap and build the SUMO network" "data,control" "$MS" \
"Propose a signalised 4-way junction in Rabat; owner confirms. Import with netconvert, define phases, 4 synthetic demand scenarios informed by footage counts (stated as an assumption). Functional open question 5."
issue "exp: controllers under ideal, camera-only and noisy sensing" "exp,control" "$MS" \
"Table: controller x sensing model x demand; plot delay vs perception error (noise from the measured P3 count error). 10 seeds, 95% CI. Headline result of the project. Technical 6.2."

# ---- P5 Edge and API ----
MS="P5 Edge and API"
issue "feat: edge event buffer with retry and backoff" "feat,infra" "$MS" \
"Bounded on-disk queue; exponential backoff; drop-oldest with a counter when full; the edge never blocks on the API. T-027."
issue "feat: structured JSON logs and Prometheus metrics" "feat,infra,mlops" "$MS" \
"JSON logs with camera and request ids (never frames, tokens or credentialed URLs); /metrics on the API (events received/rejected, latency); edge quality fields as drift signal. T-027."
issue "chore: enable Dependabot and secret scanning" "chore,infra" "$MS" \
"Weekly grouped updates for uv, GitHub Actions and Docker base images; GitHub secret scanning on. T-027."

echo "Done. Re-run if any line says FAILED or not found."
