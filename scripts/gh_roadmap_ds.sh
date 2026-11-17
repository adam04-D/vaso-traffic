#!/usr/bin/env bash
# Reset the GitHub roadmap to the CV + data science scope (docs/PROJECT.md, 2026-11-17).
# Run it yourself from the repo root, after the refocus PR is merged:  bash scripts/gh_roadmap_ds.sh
# Steps:
#   1. create milestones D1 to D5
#   2. move the still-relevant P issues to D milestones (or to `stretch`), with updated text
#   3. close every other open issue in P1 to P5 as "not planned"
#   4. delete the empty P1 to P5 milestones
#   5. create the new issues
# Safe to re-run: existing milestones and titles are skipped, and calls are retried on network errors.
set -uo pipefail

REPO="${REPO:-adam04-D/vaso-traffic}"
D1="D1 Data and EDA"
D2="D2 Detector and MLflow"
D3="D3 Domain shift"
D4="D4 Tracking and counting"
D5="D5 Traffic analytics"

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

MILESTONES_JSON="$(retry gh api "repos/$REPO/milestones?state=all&per_page=100")" \
  || { echo "Cannot list milestones, nothing changed." >&2; exit 1; }
milestone_number() { printf '%s' "$MILESTONES_JSON" | python3 -c "import json,sys; t=sys.argv[1]; print(next((str(m['number']) for m in json.load(sys.stdin) if m['title']==t), ''))" "$1"; }

milestone() {
  if [ -n "$(milestone_number "$1")" ]; then echo "milestone exists: $1"; return; fi
  retry gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null \
    && echo "milestone: $1" || echo "MILESTONE FAILED: $1"
}

issue() {
  if [ -n "$(number_of "$1")" ]; then echo "issue exists: $1"; return; fi
  retry gh issue create --repo "$REPO" --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null \
    && echo "issue: $1" || echo "ISSUE FAILED: $1"
}

# move <current title> <new title or ""> <milestone> <new body>
move() {
  local n; n="$(number_of "$1")"
  [ -z "$n" ] && [ -n "$2" ] && n="$(number_of "$2")"
  [ -z "$n" ] && { echo "not found: $1"; return; }
  local args=(--milestone "$3" --body "$4")
  [ -n "$2" ] && args+=(--title "$2")
  retry gh issue edit "$n" --repo "$REPO" "${args[@]}" >/dev/null && echo "moved #$n -> $3"
}

# stretch <title> [new body]: no milestone, label `stretch`
stretch() {
  local n; n="$(number_of "$1")"
  [ -z "$n" ] && { echo "not found: $1"; return; }
  local args=(--remove-milestone --add-label stretch)
  [ -n "${2:-}" ] && args+=(--body "$2")
  retry gh issue edit "$n" --repo "$REPO" "${args[@]}" >/dev/null && echo "stretch #$n"
}

# ---- 1. milestones ----
retry gh label create stretch --repo "$REPO" --color 5319E7 --description "Optional, after D5" --force >/dev/null && echo "label: stretch"
milestone "$D1" "Data in DVC, taxonomy, by-video split, quality checks, EDA (Q1)"
milestone "$D2" "Local MLflow, YOLO26n baseline, tracked experiments, error analysis, champion model (Q2, Q3)"
milestone "$D3" "BMD-45 to Rabat: zero-shot vs fine-tuned, learning curve (Q4)"
milestone "$D4" "Tracker, line-crossing counter, manual counts, count MAPE (Q5)"
milestone "$D5" "Flows, class mix, peaks, figures, README results (Q6)"

# ---- 2. keep and move ----
move "data: find origin and licence of the legacy CCTV.v9 dataset" "" "$D1" \
"Find where the Roboflow CCTV.v9 export came from and under which licence. Until then it stays frozen (docs/PROJECT.md section 3)."

move "data: taxonomy contract in configs/taxonomy.yaml" "" "$D1" \
"configs/taxonomy.yaml: core car, bus, truck, motorcycle, bicycle, three_wheeler; stretch grand_taxi; evaluation-only tram, emergency. A remap function in vbtso.data maps every source class (BMD-45, CCTV.v9, Rabat labels) and fails on unmapped classes. Unit-tested. PROJECT.md section 3."

move "data: ingest stage for BMD-45 at a pinned revision" "data: download BMD-45 at a pinned revision into DVC" "$D1" \
"Script in vbtso.data downloads BMD-45 from Hugging Face at a pinned revision, checks the licence file, converts it to YOLO format with the taxonomy remap, and tracks the result with DVC (push to R2)."

move "data: split the Rabat YouTube frames by video (fine-tune vs held-out test)" "" "$D1" \
"Put the 1,329 Rabat frames and labels in DVC. Split by video: 2 videos for fine-tuning, 1 held out for testing, never mixed. Record the rule in configs/data.yaml."

move "feat: training entry point with configs and run metadata" "" "$D2" \
"python -m vbtso.models.train --config configs/train/NAME.yaml. Works on the Mac (logs straight to local MLflow) and on Kaggle/Colab (writes the Ultralytics run folder for log_run). Logs config, git commit, DVC data hash, seed, machine."

move "feat: baseline detector training with per-class metrics" "" "$D2" \
"YOLO26n on BMD-45 (taxonomy-mapped). Per-class mAP50 and mAP50-95 with box counts, logged to MLflow. This is the reference run for every D2 experiment."

move "exp: X4 ablations over resolution, augmentation and model size" "exp: image size, model size and augmentation ablations" "$D2" \
"One factor at a time against the baseline: imgsz (640 vs 960), n vs s, augmentation on/off. One MLflow experiment, a comparison table and a parallel-coordinates plot. Answers Q2."

move "feat: evaluation report per class and condition" "" "$D2" \
"notebooks/03_error_analysis: per-class AP with box counts, confusion matrix, day/night/rain slices, hard cases (three-wheeler vs motorcycle, truck vs bus), worst false positives and misses shown as image grids. Answers Q3."

move "exp: X6 domain shift and X7 zero-shot baseline" "exp: domain shift from BMD-45 to Rabat" "$D3" \
"Evaluate the BMD-45 model on the held-out Rabat video (zero-shot), then fine-tune on the 2 Rabat videos and evaluate again. Learning curve: mAP vs number of Rabat images (e.g. 0, 50, 100, 250, all). All runs in MLflow; notebooks/04_domain_shift. Answers Q4."

move "feat: tracking and zone counting from a recorded video" "feat: tracking and line counting on a video" "$D4" \
"Ultralytics ByteTrack (and BoT-SORT for comparison) on a Rabat video; counts per class per line per minute written to a CSV. Uses the line-crossing counter."

move "feat: count MAPE evaluation against manual CVAT counts" "feat: count MAPE against manual counts" "$D4" \
"Count by hand the vehicles crossing the line on a held-out clip (per class, per minute; a small CSV is enough). Compare with the tracker counts: MAPE per class, logged to MLflow. Target: 10% or less. Answers Q5."

move "data: find more Rabat YouTube videos, preferably fixed-viewpoint" "" "$D4" \
"Counting needs video where the camera doesn't move. Look for Rabat (or Moroccan) fixed-viewpoint traffic videos; record source and terms for each."

stretch "exp: X1 mini anchor-free detector in PyTorch"
stretch "exp: X2 Kalman + Hungarian tracker vs ByteTrack-style"
stretch "exp: X3 focal and class-balanced losses on rare classes"
stretch "exp: X8 rare-class label QA with an offline VLM"
stretch "exp: RF-DETR Nano vs YOLO26n on the same splits"
stretch "data: label grand taxis in CVAT (stretch class)" \
"Label grand taxis on the Rabat frames with a local annotation tool (CVAT desktop or Label Studio), then train grand_taxi as an extra class."

# ---- 3. close the rest of P1 to P5 ----
OPEN_P="$(retry gh issue list --repo "$REPO" --state open --limit 500 --json number,milestone \
  -q '.[] | select(.milestone != null and (.milestone.title | test("^P[1-5] "))) | .number')" || OPEN_P=""
for n in $OPEN_P; do
  retry gh issue close "$n" --repo "$REPO" --reason "not planned" \
    --comment "Superseded by the CV + data science refocus (docs/PROJECT.md, 2026-11-17)." >/dev/null \
    && echo "closed #$n"
done

# ---- 4. delete the P milestones ----
for t in "P1 Data pipeline" "P2 Detector" "P3 Tracking" "P4 Control" "P5 Edge and API"; do
  m="$(milestone_number "$t")"
  [ -z "$m" ] && { echo "milestone gone: $t"; continue; }
  retry gh api -X DELETE "repos/$REPO/milestones/$m" >/dev/null && echo "deleted milestone: $t"
done

# ---- 5. new issues ----
issue "data: light quality checks with a unit test" "data,data-eng" "$D1" \
"A function in vbtso.data that checks a YOLO dataset: boxes inside the image, known classes, no near-duplicate images across splits (imagehash), share of empty images. Unit test on a tiny fixture. Run it before every training."

issue "data: EDA notebook on BMD-45 and Rabat frames" "data,cv" "$D1" \
"notebooks/01_eda: images and boxes per class and split, box size and aspect ratio per class, day/night/rain, empty images, near-duplicates, example grids per class. Findings in reports/. Answers Q1."

issue "chore: local MLflow server and log_run importer" "chore,mlops" "$D2" \
"just mlflow (done in the refocus PR). Add vbtso.models.log_run: import an Ultralytics run folder from Kaggle/Colab into local MLflow (params from args.yaml, per-epoch metrics from results.csv, plots and weights as artefacts, tags). Unit test on a fake run folder."

issue "exp: class weighting with cls_pw for rare classes" "exp,cv" "$D2" \
"Baseline vs cls_pw 0.5 and 1.0. Watch per-class AP of three_wheeler, bus and truck and the cost on car. One MLflow experiment."

issue "feat: register the champion detector in the MLflow Model Registry" "feat,mlops" "$D2" \
"Register the best run as vbtso-detector, alias champion. Small script that compares a candidate with the champion per core class on the fixed Rabat test and moves the alias only if no core class gets worse."

issue "feat: line-crossing counter as a pure function" "feat,cv" "$D4" \
"vbtso.tracking.count: given tracks (id, class, centre per frame) and a line, count crossings per class and direction, each track counted once. Unit tests: crossing, touching, back-and-forth, ID switch."

issue "feat: traffic analytics from counts" "feat,data-eng" "$D5" \
"vbtso.analytics + notebooks/05_traffic_analytics: flow per class per minute, class mix, peaks, rolling averages, day vs night if data allows; optional rough speed from track displacement. Figures in reports/. Answers Q6."

issue "docs: results section in the README" "docs" "$D5" \
"Short results section: key tables (detector per class, domain shift, count MAPE) and 2-3 figures, each linked to its MLflow run and notebook. Honest limits paragraph."

echo "Done. Re-run if any line says FAILED or not found."
