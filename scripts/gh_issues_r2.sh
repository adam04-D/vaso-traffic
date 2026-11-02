#!/usr/bin/env bash
# Apply review R2 (data engineering) to the P1 milestone: update, close and create issues.
# Run it yourself from the repo root:  bash scripts/gh_issues_r2.sh
# Safe to re-run: existing titles are skipped, and every call is retried on network errors.
set -uo pipefail

REPO="${REPO:-adam04-D/vaso-traffic}"
MS="P1 Data pipeline"

retry() {
  local n
  for n in 1 2 3 4; do
    "$@" && return 0
    [ "$n" -lt 4 ] && { echo "  retry $n/3 in $((n*3)) s..." >&2; sleep $((n*3)); }
  done
  return 1
}

ISSUES_JSON="$(retry gh issue list --repo "$REPO" --state all --limit 500 --json number,title,state)" \
  || { echo "Cannot reach GitHub, nothing changed. Re-run later." >&2; exit 1; }
number_of() { printf '%s' "$ISSUES_JSON" | python3 -c "import json,sys; t=sys.argv[1]; print(next((str(i['number']) for i in json.load(sys.stdin) if i['title']==t), ''))" "$1"; }

issue() {
  if [ -n "$(number_of "$1")" ]; then echo "issue exists: $1"; return; fi
  retry gh issue create --repo "$REPO" --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null \
    && echo "issue: $1" || echo "ISSUE FAILED: $1"
}

# 1. Close the footage issue: answered by the owner (no own recording), see functional D-009
n="$(number_of "data: find fixed-camera footage for Rabat")"
if [ -n "$n" ]; then
  retry gh issue close "$n" --repo "$REPO" --reason "not planned" \
    --comment "Resolved by review R2: no own fixed-camera recording is available. Rabat is represented by public data (MoVITS) and the YouTube frames as an out-of-domain test. See docs/review/R2-data-engineering.md and functional_spec D-009. Reopen if a vantage point appears." \
    && echo "closed #$n"
fi

# 2. Narrow the licence issue to the sources actually kept
n="$(number_of "data: verify licences of public datasets")"
if [ -n "$n" ]; then
  retry gh issue edit "$n" --repo "$REPO" \
    --title "data: confirm licences and contents of BMD-45, MoVITS and UA-DETRAC" \
    --body "From review R2 (docs/review/R2-data-engineering.md, section 3):
- BMD-45: read the LICENSE file in the HF repo iisc-aim/BMD-45 (paper says CC BY 4.0; HF metadata blank). Record size and class list.
- MoVITS (Mendeley 10.17632/5jcg5vfx58): fixed or moving camera? video or images? classes, size, licence CC BY-NC-SA 4.0.
- UA-DETRAC: find the official licence; usable for counting evaluation only if confirmed.
Output: the sources table in technical_spec 2.3 updated, *verify* marks removed." \
    && echo "edited #$n"
fi

# 3. New P1 issues
issue "data: find origin and licence of the legacy CCTV.v9 dataset" "data,data-eng" "$MS" \
"Owner: find the Roboflow Universe project the CCTV.v9 export came from and its licence. Then decide: keep for training only (never published) or drop. Functional open question 7."

issue "data: taxonomy contract in configs/taxonomy.yaml" "data,data-eng,cv" "$MS" \
"Core: car, bus, truck, motorcycle, bicycle, three_wheeler. Local: grand_taxi (stretch). Evaluation-only: tram, emergency. One mapping per source (BMD-45, MoVITS, legacy, YouTube). Unmapped class = pipeline error. Unit tests. Technical 2.3, T-019."

issue "data: catalogue.parquet schema and builder" "data,data-eng" "$MS" \
"One row per image: image_id, sha256, source, source_revision, camera_id/scene_id, condition, licence, split, per-class box counts. Built in src/vbtso/data, DVC-tracked, pyarrow. Unit tests on a fixture. T-019."

issue "data: ingest stage for BMD-45 at a pinned revision" "data,data-eng" "$MS" \
"DVC stage that downloads BMD-45 from Hugging Face at a pinned commit, verifies checksums, converts to the common format with the taxonomy map. Public data is not pushed to R2. T-019."

issue "data: validate stage as a hard gate, with a CI fixture" "data,data-eng,mlops" "$MS" \
"Checks: boxes in bounds, known classes, no perceptual-hash near-duplicate across splits, minimum boxes per class per split, empty images <= 15%. Runs in dvc repro and in CI on a tiny fixture dataset. T-019."

issue "chore: self-hosted CVAT in docker compose" "chore,infra,data-eng" "$MS" \
"Add CVAT Community to docker-compose (profile cvat), document start/stop, export format (YOLO / CVAT video tracks) and backup in the developer guide. T-020."

issue "data: label grand taxis in CVAT (stretch class)" "data,data-eng,cv" "$MS" \
"Re-annotate grand taxis in the YouTube frames and MoVITS. Target >= 300 boxes; below that, drop the class and say so. Results reported as out-of-domain. Functional D-009."

issue "data: find more Rabat YouTube videos, preferably fixed-viewpoint" "data,data-eng" "$MS" \
"Search for more Rabat street videos: time-lapses, live streams, footage filmed from a balcony or a fixed point first; drive-throughs second. Record URL, date, conditions (day/night/rain), viewpoint (fixed/moving) and licence notes in a sources table. Each new video is a new scene for the split-by-video rule (fine-tune vs held-out test). Never redistributed. Review R2 section 7, functional D-009."

issue "data: split the Rabat YouTube frames by video (fine-tune vs held-out test)" "data,data-eng" "$MS" \
"Assign each Rabat video to fine-tune or held-out test in the catalogue (scene_id = video). Initial rule: 2 videos fine-tune, 1 held out; the held-out video is never trained on. Re-balance when more videos arrive (keep at least one night or rain scene in the test). Technical 2.3, T-018."

echo "Done. Re-run if any line says FAILED."
