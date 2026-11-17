# VBTSO: project plan

The single reference for what this project does, which data it uses, and in what order the work happens. It replaces the older functional and technical specs and the R1–R7 review (all still in the git history, PR #39).

## 1. Goal

A **computer vision and data science** project on traffic video:

1. **Detect** vehicles in traffic images, including local classes (three-wheelers, and grand taxis as a stretch goal).
2. **Track and count** them in video, and measure how accurate the counts are.
3. **Analyse** the counts: flows per class over time, class mix, peaks.
4. **Study domain shift**: train on fixed CCTV from India (BMD-45), then measure how much is lost on Rabat streets and how much fine-tuning gets back.

Every model run is tracked in **MLflow** (running locally), so experiments can be compared and the best model registered.

It isn't a production system, and it doesn't control traffic signals. The name is historical: signal timing could come later as an analysis on top of the counts.

## 2. Questions the project answers

| # | Question | Where |
|---|---|---|
| Q1 | What do the datasets look like: class balance, box sizes, day/night, duplicates, label problems? | D1, `notebooks/01_eda` |
| Q2 | Which training choices matter (image size, model size, augmentation, class weighting)? | D2, `02_experiments` |
| Q3 | Where does the detector fail, and on which classes and conditions? | D2, `03_error_analysis` |
| Q4 | How much accuracy is lost going from India CCTV to Rabat streets, and how many Rabat images does it take to recover? | D3, `04_domain_shift` |
| Q5 | How accurate are the counts from tracking, compared with a manual count? | D4 |
| Q6 | What do the counts say about the traffic: flow per minute, class mix, peaks? | D5, `05_traffic_analytics` |

## 3. Data

| Source | What | Licence | Role |
|---|---|---|---|
| **BMD-45** (Hugging Face) | 45K fixed-CCTV images, 14 classes, Indian cities | CC BY 4.0 | Training base, downloaded at a pinned revision |
| **Rabat YouTube frames** | 1,329 frames from 3 street videos (day, night, rain), filmed from a moving car | Third-party: used for research only, never redistributed | Fine-tune on 2 videos, test on the 3rd |
| More Rabat videos | Ideally a fixed viewpoint, for counting | Checked per video | Counting ground truth (D4) |
| Legacy `CCTV.v9` (Roboflow) | Hackathon dataset, 8 classes | **Unknown: the owner is checking** | Frozen until its licence is known |

Rules (kept deliberately light):
- **DVC + Cloudflare R2** version the data, so the Mac, Kaggle and Colab pull the same version. Raw data and weights never go in git.
- **Split by video or camera, never by frame.** Frames from the same video are near-copies, so a random split leaks.
- **Light quality checks** run as a function with a test, not a big pipeline: boxes inside the image, known classes, no near-duplicates across splits.
- Rare classes are always reported **with their box counts**, never averaged away.

### Taxonomy (`configs/taxonomy.yaml`)

| Kind | Classes |
|---|---|
| Core (trained) | `car`, `bus`, `truck`, `motorcycle`, `bicycle`, `three_wheeler` (auto-rickshaw and triporteur) |
| Stretch | `grand_taxi` |
| Evaluation only (too rare) | `tram`, `emergency` |

Every source class maps to one of these, and an unmapped class is an error.

## 4. Modelling and tracking

- **Detector:** YOLO26n (Ultralytics) by default, with the `s` size tried if time allows. RF-DETR Nano is a stretch comparison.
- **Imbalance:** more data from BMD-45 first, then Ultralytics' `cls_pw`, then oversampling and copy-paste. Custom focal or class-balanced losses are a stretch.
- **Training** runs from configs (`configs/train/*.yaml`) on Kaggle, Colab or the Mac, through one entry point.
- **Tracking:** the ByteTrack or BoT-SORT tracker built into Ultralytics. Counting is our own line-crossing function: pure Python and unit-tested.

## 5. Metrics

| What | Metric |
|---|---|
| Detection | mAP50 and mAP50-95 overall and **per class with box counts**, per condition (day/night/rain), on the held-out Rabat video |
| Domain shift | The same metrics before and after fine-tuning, and mAP against the number of Rabat images |
| Counting | Count MAPE per class against a manual count (target ≤ 10%) |
| Analytics | Descriptive statistics and plots. No accuracy claim. |

Published numbers use 3 seeds where it's affordable.

## 6. MLflow (local)

- `just mlflow` starts the server on `http://127.0.0.1:5000`. Its store is in `mlruns/` (SQLite plus artefacts), which is git-ignored. Back it up with `just mlflow-backup`.
- **Mac runs** log straight to the server.
- **Kaggle and Colab runs** can't reach the Mac. They save the Ultralytics run folder, which you download, and `log_run` imports it locally. Params come from `args.yaml` and per-epoch metrics from `results.csv`; plots and weights are stored as artefacts. Tags record the git commit, the DVC data hash and the machine.
- **One experiment per question** (Q2 to Q5). Every run logs its config, data version, per-class metrics and confusion matrix.
- **Model Registry:** the best detector is registered as `vbtso-detector` with the alias `champion`, and a new version only becomes champion if it isn't worse on any core class.
- **Monitoring** in the data science sense: track per-class metrics on the fixed Rabat test across model versions, and inference statistics per video (confidence, class mix).

## 7. Roadmap

| Milestone | Delivers |
|---|---|
| **D1 Data and EDA** | BMD-45 and Rabat frames in DVC, taxonomy and mapping, by-video split, quality checks, EDA notebook (answers Q1), CCTV.v9 licence |
| **D2 Detector and MLflow** | Local MLflow and the `log_run` importer, YOLO26n baseline, tracked experiments (Q2), error analysis (Q3), champion in the registry |
| **D3 Domain shift** | Zero-shot vs fine-tuned on the Rabat test, learning curve (Q4) |
| **D4 Tracking and counting** | Tracker, line counter, manual counts, count MAPE in MLflow (Q5) |
| **D5 Traffic analytics** | Flows, class mix, peaks, figures, and the README results section (Q6) |
| Stretch | RF-DETR comparison, own mini detector, own Kalman + Hungarian tracker, focal/class-balanced losses, offline VLM label QA, Hugging Face demo |

Each milestone ends with its notebook and a short findings section in `reports/`.

## 8. Repository layout

```
configs/      taxonomy.yaml, data.yaml, train/*.yaml
data/         DVC-tracked, not in git
notebooks/    01_eda ... 05_traffic_analytics;  legacy/ = hackathon notebooks (reference only)
src/vbtso/    data/  models/  tracking/  analytics/   (reusable code; notebooks import it)
reports/      figures and findings
tests/        fast unit tests on pure functions (CI has no PyTorch)
```

## 9. Decision log

| Date | Decision |
|---|---|
| 2026-11-02 | AGPL-3.0 licence (Ultralytics is AGPL). uv + just + ruff + pytest + pre-commit, plus CI on every PR. |
| 2026-11-02 | DVC with Cloudflare R2 as the data remote. |
| 2026-11-02 | BMD-45 is the training base. The Rabat frames are split by video. The taxonomy is as in section 3. Imbalance is handled with `cls_pw`. YOLO26n is the default model. Counting is measured with MAPE. |
| 2026-11-17 | **Refocus on computer vision and data science.** Dropped: Docker images, FastAPI service, edge worker, local S3 store, SUMO and signal controllers, catalogue/validate-gate pipeline, self-hosted CVAT. MLflow runs **locally** instead of on DagsHub. |
