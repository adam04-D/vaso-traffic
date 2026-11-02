# Technical Specification: Vision-Based Traffic Signal Optimisation (VBTSO)

> **Living document.** Updated with every technology or feature decision; each change is logged in the [Decision log](#10-decision-log) and [Changelog](#11-changelog).
> Status tags: `[Current]` in the repo today · `[Critiqued]` reviewed and found weak · `[Proposed]` suggested · `[Decided]` agreed.
> Companion: [functional_spec.md](functional_spec.md). The stack is **derived from requirements**: where a tool is named, the requirement it serves is stated.

---

## 1. Requirements that drive the stack `[Proposed]`

| ID | Requirement | Drives |
|---|---|---|
| R1 | Any experiment can be reproduced from a git commit (code + data + config) | Data versioning, configs, pinned deps |
| R2 | Metrics must not be inflated by correlated frames | Scene-level splits |
| R3 | Training fits free/low-cost GPUs (Kaggle/Colab) and a Mac for development | Small models, remote runs |
| R4 | Inference runs on a CPU-class edge device | Export and measured latency |
| R5 | Flow, not just boxes: counts per zone over time | Tracking + zone counting |
| R6 | The controller is validated without a real intersection | Simulation |
| R7 | Raw images never leave the edge | Counts-only event schema |

## 2. Data engineering

### 2.1 Current state `[Current]` `[Critiqued]`

Notebook `01_data_engineering.ipynb`: frames every 5 s from YouTube driving videos → watermark masking → three filters (darkness, Laplacian blur, perceptual-hash near-duplicates, moving rejects aside) → manual Roboflow upload. Storage is Google Drive mounted in Colab with hardcoded paths. `notebooks/02` unzips a hand-built `dataset.zip` (made by a gitignored `zip_dataset.py` that is not in the repo).

Problems: not reproducible (R1), no versions, splits not scene-aware (R2), manual steps, no dataset documentation.

### 2.2 Target pipeline `[Proposed]`

```mermaid
flowchart TD
    SRC[Sources: public datasets,<br/>own recordings, synthetic] --> RAW[(Raw store<br/>S3-compatible bucket)]
    RAW --> EXT[Frame extraction<br/>+ scene id + metadata]
    EXT --> FIL[Quality filters<br/>dark / blur / near-duplicate]
    FIL --> REV[Manual annotation<br/>+ label QA]
    REV --> SPL[Scene-level split<br/>train / val / test]
    SPL --> VER[(Versioned dataset<br/>DVC + dataset card)]
    VER --> TRAIN[Training]
    VER -.->|publish release| HF[(Hugging Face Hub<br/>dataset + model cards)]
    TRAIN -.->|publish weights| HF
```

- Each stage is a script with a config, run with a pipeline tool (DVC stages), so `dvc repro` rebuilds the dataset.
- Every image carries `scene_id`, `source`, `condition` (day/night/rain), `licence`.
- A **dataset card** records origin, licence, class counts, known biases, and the exact split rule.

### 2.3 Sourcing decision matrix `[Proposed]`

The single largest weakness is data. Matrix to fill in; entries marked *verify* were not confirmed from official licence texts.

| Source | Domain match | Labels | Licence | Effort | Notes |
|---|---|---|---|---|---|
| Own YouTube drive videos (current) | Poor (moving camera) | None | Unclear; platform terms, third-party footage | Low | Keep as a hard out-of-domain **test**, not as the training core. |
| UA-DETRAC | Good (fixed traffic cameras) | Boxes + tracks | *Verify* (research terms likely) | Low | Also gives tracking ground truth for T2. |
| VisDrone | Medium (aerial) | Boxes | *Verify* | Low | Different viewpoint; use for robustness only. |
| BDD100K | Medium (dashcam) | Boxes | *Verify* (sources conflict: BSD-3 vs. "other") | Low | Day/night/rain variety. |
| Roboflow Universe public sets | Variable | Boxes | Per dataset | Low | Check each licence; label taxonomies differ. |
| Synthetic (CARLA / SUMO + renderer) | Controllable | Free, exact | Own | Medium | Can generate rare classes and weather; sim-to-real gap to measure. |
| Own fixed-camera recording | Best | Manual | Own | High | Only if a safe vantage point is available; plate/face privacy applies. |

### 2.4 Split policy `[Proposed]`

Frames from one video are near-identical neighbours. A random frame split puts almost-the-same image in train and test and reports mAP that will not hold on a new scene.

```mermaid
flowchart LR
    subgraph BAD["Frame-level split (leaky)"]
        V1[Video A frames 1..n] --> TR1[train]
        V1 --> TE1[test]
    end
    subgraph GOOD["Scene-level split"]
        VA[Video A] --> TR2[train]
        VB[Video B] --> TE2[test]
        VC[Video C] --> VA2[val]
    end
```

Rule: split by `scene_id`; at least one night and one rain scene are held out entirely. Rare classes get reported with their raw box counts.

### 2.5 Storage `[Decided]`

Replace Drive with S3-compatible object storage as the DVC remote. Reasons: versioned, scriptable, usable from Kaggle/Colab/Mac with the same commands, and it is what real teams do.

```mermaid
flowchart LR
    GIT[(Git repo<br/>code + .dvc pointers)] --- DVC{{DVC}}
    DVC -->|default, shared| R2[(Cloudflare R2<br/>remote r2)]
    DVC -->|offline dev, tests| MIN[(S3Mock in Docker<br/>remote local, localhost only)]
    R2 --- KG[Kaggle / Colab<br/>training]
    R2 --- MAC[Mac<br/>development]
    MIN --- MAC
```

- **`r2`** is the shared, default remote. It has to be cloud-hosted because Kaggle and Colab cannot reach a store running on the Mac. Free-tier limits and egress terms to be re-checked when the bucket is created (*verify*). Backblaze B2 is the fallback if R2 proves unsuitable.
- **`local`** is a throwaway S3-compatible store (Adobe S3Mock) under Docker Compose, bound to `localhost`. It lets everything be developed and tested offline and without cloud credentials. It is not a production store. MinIO was the first choice, but its images could no longer be pulled from the public registries (checked 2026-11-02); the push, pull and restart-persistence round trip was verified against S3Mock with DVC 3.67.
- Credentials never enter git: AWS-style environment variables (from `.env`, or Kaggle/Colab Secrets) or `.dvc/config.local`.
- Commands and per-machine setup are in `docs/DEVELOPER_GUIDE.md`, section 8.

### 2.6 Hugging Face Hub `[Proposed]`

Role: the **public distribution layer**, not the working store. DVC + the bucket remain the pipeline and versioning backbone (they carry the reproducibility skill, R1); Hugging Face holds the finished artefacts.

| Artefact | On the Hub | Why |
|---|---|---|
| Dataset releases | Dataset repo with a dataset card (origin, licences, class counts, split rule) | Public, versioned, recruiter-visible. Only data whose licences allow redistribution is published; otherwise publish scripts and metadata only. |
| Trained weights | Model repo with a model card (metrics per class, training data version, limits) | One place to pull a released model. |
| Demo (later) | A Space running the detector on uploaded video | Free hosting for a portfolio demo; not MVP. |

Rule: a Hub release is cut from a tagged git commit + DVC dataset version, so it stays reproducible. Evaluation stays metric-based (mAP, count error); no judge model, and no VLM pre-labelling (rejected, see T-008).

## 3. Modelling

### 3.1 Current state `[Current]` `[Critiqued]`

`notebooks/02_model_training.ipynb`: YOLO26n (2,572,280 params), 8 classes (`Grand Taxi, Triporteur, bus, camion, moto, tram, urgence, voiture`), AdamW, lr0 0.001, cosine LR, mosaic/mixup/copy-paste, trained on Colab/Kaggle, exported to ONNX (opset 12).

| Issue | Detail |
|---|---|
| No recorded result | Saved outputs show the config but no final metric; `models/` is empty. |
| Documentation/code drift | Text describes V2 (300 epochs, `image_weights`, `fl_gamma`), while the config shown is V1 (100 epochs) and has neither argument. I believe Ultralytics does not support `image_weights`/`fl_gamma` in its YOLO trainer (*verify against the installed version*). |
| Imbalance | See 3.3. |
| Inconsistent model | `main.ipynb` uses YOLO11n and 4 classes. |
| Everything lives in notebook cells | Not testable or reusable. |

### 3.2 Model choice `[Proposed]`

YOLO26 is an NMS-free Ultralytics model family released around late 2025 (sources disagree on the exact date) with nano to extra-large sizes. Ultralytics' own docs recommend YOLO26 and YOLO11 for stable production use. We keep YOLO26n as the default **but benchmark it** against YOLO11n (and optionally an RT-DETR-class model) on the same scene-level split before deciding, because the choice should be a measurement.

### 3.3 Imbalance handling `[Proposed]`

Current counts: voiture 7,109 (89.8%), camion 214, moto 203, bus 190, Grand Taxi 168, tram 12, Triporteur 11, urgence 7.

```mermaid
xychart-beta
    title "Boxes per class (current dataset)"
    x-axis [voiture, camion, moto, bus, taxi, tram, tricycle, urgence]
    y-axis "boxes" 0 --> 7500
    bar [7109, 214, 203, 190, 168, 12, 11, 7]
```

With 7 to 12 examples, a class cannot be learned or even evaluated reliably: a test split may hold 0 or 1 instance. Options, in order of cost:
1. More data for those classes (public sets, synthetic generation, targeted collection). Strongest fix.
2. Class-balanced image sampling (a custom sampler or oversampling the file list; Ultralytics' built-in options to be verified).
3. Loss re-weighting / focal-style loss via a custom trainer.
4. Merge or drop classes that cannot be evaluated, and say so.
Evaluation always reports per-class AP with the box count next to it.

### 3.4 Licence `[Decided]`

Ultralytics code and weights are AGPL-3.0 (with a paid Enterprise licence for closed-source use). The repo was MIT, which conflicts once the project imports and distributes AGPL code. Decision T-013: the repo is **AGPL-3.0**, matching its main dependency. Consequence: anyone may reuse the code but must publish their changes, including when it is offered as a network service. If a client ever needs closed-source use, the options are an Ultralytics Enterprise licence or a permissively licensed detector (e.g. Apache-2.0 RT-DETR).

### 3.5 Experiment tracking `[Proposed]`

```mermaid
erDiagram
    DATASET_VERSION ||--o{ RUN : trains
    CONFIG ||--o{ RUN : parameterises
    GIT_COMMIT ||--o{ RUN : produces
    RUN ||--o{ METRIC : logs
    RUN ||--o{ MODEL_ARTIFACT : saves
    MODEL_ARTIFACT ||--o{ EXPORT : converts_to
    EXPORT ||--o{ BENCHMARK : measured_on
```

A run is reproducible when (commit, dataset version, config) are all recorded. Tool: Weights & Biases or MLflow (choose one; MLflow is self-hostable). Hyperparameters move from notebook cells to `configs/*.yaml`.

## 4. Code structure `[Decided]`

Notebooks become exploration only; logic lives in the `vbtso` package (`src` layout).

```text
.
├── README.md  LICENSE  CONTRIBUTING.md
├── functional_spec.md / technical_spec.md
├── pyproject.toml            # single source of dependencies (extras: train, edge, api; group: dev)
├── uv.lock                   # exact versions, committed
├── .python-version           # 3.12
├── justfile                  # task runner: setup, lint, test, check, ...
├── .pre-commit-config.yaml   # ruff, nbstripout, file hygiene
├── .env.example              # variable names only, never values
├── dvc.yaml  .dvc/           # pipeline + data remote (milestone M2)
├── configs/                  # data.yaml, train/*.yaml, edge.yaml, zones/*.yaml
├── src/vbtso/
│   ├── data/                 # extract, filter, split, validate        (P1)
│   ├── models/               # train, eval, export                     (P2)
│   ├── tracking/             # tracker, zone counter                   (P3)
│   ├── control/              # fixed_time, webster, max_pressure, rl   (P4)
│   └── api/                  # event schema v1, ingestion service      (P5)
├── tests/                    # unit tests on pure functions + schema tests
├── notebooks/                # exploration only (legacy, ruff-excluded)
├── docs/                     # DEVELOPER_GUIDE.md, legacy_results.md
├── docker/                   # edge and API images (milestone M3)
├── scripts/                  # github_setup.sh
└── .github/                  # workflows, issue and PR templates
```

Dependency model: the core install is tiny (`numpy`, `pyyaml`). Heavy stacks are **extras** so each environment installs only what it needs: `train` on Mac/Kaggle/Colab, `edge` on the device and in the edge image, `api` in the service image. Developer tools are a uv **dependency group** (`dev`) and are never installed on Kaggle/Colab or in images. The old `requirements.txt` (which lacked `pyyaml`, `imagehash`, `matplotlib`, `Pillow`) is removed.

## 5. Edge runtime

### 5.1 Current state `[Current]` `[Critiqued]`

`main.ipynb` cell 7 loops over RTSP frames, runs the model, and every 30 s counts boxes **in one frame** and posts them. Problems: a single frame count is not flow (R5); no tracking, so the same car is not recognised across frames; thresholds hardcoded; "QUEUED" is printed but nothing is queued; credentials in the example URL; reconnect logic creates a new capture without releasing the old one.

### 5.2 Target design `[Proposed]`

```mermaid
sequenceDiagram
    participant S as Stream / file
    participant D as Detector
    participant T as Tracker
    participant Z as Zone counter
    participant A as Aggregator
    participant P as Publisher
    S->>D: frame
    D->>T: boxes + classes
    T->>Z: tracks with ids
    Z->>A: line crossings, queue occupancy
    A->>P: every N s: counts per zone/class
    P-->>P: retry queue if API offline
    P->>API: POST event (versioned schema)
```

- Tracker: ByteTrack-style (available in Ultralytics' tracking mode, *verify*), giving stable IDs.
- Zones/lines: per-camera config in `configs/zones/<camera>.yaml` (polygons per approach/lane).
- Queue estimate: vehicles stationary inside an approach zone.
- A recorded video can replace the stream, so the whole path is testable offline.

### 5.3 Export and benchmarks `[Proposed]`

Formats to compare: PyTorch, ONNX, OpenVINO, NCNN, TensorRT (hardware permitting). The notebook's claims ("RPi5 NCNN ~10 to 14 FPS", "Jetson Orin 80+ FPS") are unsourced `[Critiqued]`; replace them with measured numbers on the device we actually have (the Mac CPU at minimum), with latency, FPS and accuracy drop recorded per format.

## 6. Control and simulation

### 6.1 Formulation `[Proposed]`

```mermaid
flowchart LR
    S["State: queue per approach,<br/>current phase, time in phase"] --> POL["Policy"]
    POL --> A["Action: next phase<br/>and/or green duration"]
    A --> ENV["Intersection dynamics<br/>(SUMO)"]
    ENV --> R["Objective: min average delay<br/>(or max throughput)"]
    ENV --> S
```

| Tier | Controller | Input needed |
|---|---|---|
| C0 | Fixed-time plan | None |
| C1 | Webster optimal cycle / queue-proportional split | Flow per approach |
| C2 | Max-pressure | Queue per approach (and downstream) |
| C3 | RL (optional) | Same state, plus training episodes |

The state the controller needs must be producible by T2 (zone queue + counts). If perception cannot supply it, the controller is not valid. This is the main coupling risk between the two halves.

### 6.2 Validation `[Proposed]`

SUMO scenario of one intersection (a real Rabat junction can be modelled from OpenStreetMap; to be chosen). Compare C0 to C2 (and C3) on average delay, queue length, throughput, over several demand levels and random seeds. Two experiments:
1. Ideal sensing (ground-truth counts from SUMO).
2. Noisy sensing (counts with the error measured on real video), to show how perception error propagates into control quality.

Published SUMO benchmarks (e.g. RESCO) report fixed-time, greedy and max-pressure baselines against learning methods, and note that max-pressure is hard to beat, which is why C2 is the real bar for C3 (*benchmark claims from search results; read RESCO's paper before quoting numbers*).

## 7. Integration `[Proposed]`

Replace the ad-hoc payload with a versioned schema (counts only, R7). Candidate v1:

```json
{
  "schema_version": "1.0",
  "camera_id": "string",
  "window_start": "2026-10-20T10:00:00Z",
  "window_seconds": 30,
  "zones": [
    {
      "zone_id": "north_approach",
      "crossings": {"car": 12, "bus": 1, "motorcycle": 3},
      "queue_vehicles": 4
    }
  ],
  "quality": {"fps": 14.2, "mean_confidence": 0.71}
}
```

n8n is optional glue; a small FastAPI service that validates the schema and stores events would be a more portable portfolio component (decision pending). No images, no coordinates, no plate text in the payload.

## 8. Testing and validation `[Proposed]`

| Layer | Test |
|---|---|
| Data | Schema checks, no scene appears in two splits, class counts match the card. |
| Model | Per-class AP on the held-out scenes; regression threshold in CI on a tiny fixture. |
| Tracking/counting | Count error vs. manual counts on labelled clips. |
| Control | Simulation comparison with fixed seeds. |
| Integration | JSON schema validation. |

## 9. Custom implementations and ablations `[Proposed]`

The pipeline uses off-the-shelf components (Ultralytics detector, ByteTrack-style tracker, SUMO). This section lists the parts we also write ourselves, each compared against its off-the-shelf counterpart on the same data, so the project demonstrates the underlying algorithms and not only the tooling. Every item is additive: the baseline pipeline in sections 2 to 7 works without any of them, and an item is dropped if it does not pay off.

| ID | Component | What we write | Compared against | Acceptance check |
|---|---|---|---|---|
| X1 | Mini detector | Small anchor-free detector in PyTorch: backbone, detection head, GIoU loss, NMS | YOLO26n on the same scene-level split | Per-class mAP50 reported for both; gap and likely causes documented. |
| X2 | Tracker | Kalman filter (constant-velocity) plus Hungarian matching on IoU | ByteTrack-style tracker from Ultralytics | Same clips: ID switches and zone-count error for both. |
| X3 | Imbalance loss | Focal loss and class-balanced loss implemented from the papers | Default loss; oversampling of rare classes | Ablation table with per-class AP for `urgence`, `Triporteur`, `tram`; replaces the unsupported `fl_gamma` setting (section 3.3). |
| X4 | Ablation study | Controlled sweeps over input resolution, augmentation and model size | The baseline run | One run per factor, one change at a time, all logged in the tracker (section 3.5); results in a single table. |
| X5 | RL controller (C3) | DQN or PPO agent over the SUMO state defined in section 6.1 | C2 max-pressure, C0 fixed-time | Average delay over several demand levels and seeds; reported as a win only if it beats max-pressure. |
| X6 | Domain-shift experiment | Train on public data, test on Rabat footage, then fine-tune | Zero-shot result | mAP before and after fine-tuning; a plot of mAP against the number of Rabat images used. |
| X7 | Zero-shot baseline | Evaluation script running an open-vocabulary detector (e.g. Grounding DINO, OWL-ViT) on the held-out Rabat frames, no training | Our fine-tuned detector | Extra row in the X6 table: mAP50 per class, zero-shot versus trained. Offline only. |
| X8 | Rare-class label QA | Offline script: a small open-source VLM classifies cropped boxes of `urgence`, `Triporteur`, `tram`; disagreements are queued for manual re-check | Manual review alone | Number of label errors found, and per-class AP before and after correction. The VLM never writes labels. |

```mermaid
flowchart LR
    BASE["Baseline pipeline<br/>(sections 2 to 7)"] --> X1 & X2 & X3 & X4 & X5 & X6 & X7 & X8
    X1["X1 mini detector"] --> CMP1["vs YOLO26n"]
    X2["X2 tracker"] --> CMP2["vs ByteTrack-style"]
    X3["X3 imbalance losses"] --> CMP3["vs default loss"]
    X4["X4 ablations"] --> CMP4["vs baseline run"]
    X5["X5 RL agent"] --> CMP5["vs max-pressure"]
    X6["X6 domain shift"] --> CMP6["vs zero-shot"]
    X7["X7 zero-shot baseline"] --> CMP7["vs fine-tuned"]
    X8["X8 rare-class QA"] --> CMP8["vs manual review only"]
```

Order of work: X3 and X4 first (cheap, they reuse the existing training loop), then X2, then X1, then X6, with X7 beside it (same test set) and X8 once the rare-class crops are annotated. X5 comes last and only after C2 works in SUMO (section 6.2). Each item gets its own tracked run and a short write-up in the repo, whether or not it beats the baseline.

## 10. Decision log

| ID | Date | Decision | Status | Requirement |
|---|---|---|---|---|
| T-001 | 2026-10-20 | S3-compatible bucket + DVC instead of Google Drive | Decided (provider: Cloudflare R2, see T-016) | R1, R3 |
| T-002 | 2026-10-20 | Split by scene, not frame | Proposed | R2 |
| T-003 | 2026-10-20 | Keep YOLO26n as default, benchmark vs YOLO11n | Proposed | R3, R4 |
| T-004 | 2026-10-20 | Tracking + zone counting replaces per-frame counts | Proposed | R5 |
| T-005 | 2026-10-20 | SUMO as controller validation ground truth | Proposed | R6 |
| T-006 | 2026-10-20 | Experiment tracker: W&B or MLflow | Open | R1 |
| T-007 | 2026-10-20 | Integration layer: n8n vs FastAPI | Open | R7 |
| T-008 | 2026-10-20 | VLM/foundation-model pre-labelling and judge-model evaluation | Rejected (owner); amended 2026-11-02 by T-012 | Manual annotation + metric-based evaluation instead; avoids extra complexity |
| T-009 | 2026-10-20 | Hugging Face Hub for publishing datasets, weights, model/dataset cards (DVC stays the working store) | Decided | R1 |
| T-010 | 2026-11-02 | Project renamed VBTSO (see functional D-008); repo `vaso-traffic`; use `vbtso` as the Python package name when `src/` is created | Decided | Naming consistency |
| T-011 | 2026-11-02 | Add custom implementations and ablations X1 to X6 (section 9), each compared against its off-the-shelf counterpart; all optional and additive | Proposed | R3, R4, R5, R6 |
| T-012 | 2026-11-02 | Allow VLMs offline only: rare-class label QA (X8) and zero-shot baseline (X7). Still rejected: pre-labelling, judge-model evaluation, any VLM in the edge runtime or payload | Decided | R2, R3; keeps the privacy boundary and the metric-based evaluation |
| T-013 | 2026-11-02 | Repo licence AGPL-3.0 (replaces MIT) | Decided | Matches Ultralytics AGPL-3.0 (section 3.4) |
| T-014 | 2026-11-02 | Workflow: protected main, branch + PR for every change, squash-merge, Conventional Commits (extra types `exp`, `data`), GitHub issues and milestones; see CONTRIBUTING.md and docs/DEVELOPER_GUIDE.md | Decided | Traceability, enterprise-style process |
| T-015 | 2026-11-02 | Environment: uv (Python 3.12, `pyproject.toml` + committed `uv.lock`) replaces conda/pip/`requirements.txt`; `just` as task runner; ruff + pytest; pre-commit (ruff, nbstripout); heavy deps as extras (`train`, `edge`, `api`), tooling as a `dev` group | Decided | R1, R3 |
| T-016 | 2026-11-02 | DVC remotes: `r2` (Cloudflare R2, shared, default) and `local` (S3Mock in Docker, offline dev); credentials only through environment variables or git-ignored `.dvc/config.local`; store bound to localhost, no real data | Decided | R1, R3; Kaggle/Colab cannot reach a MinIO on the Mac, so the shared remote must be cloud-hosted |

## 11. Changelog

| Date | Change |
|---|---|
| 2026-11-02 | M2 data platform: DVC remotes r2 + local (T-016), docker-compose with an S3Mock dev store (MinIO images unavailable), just recipes, guide section 8. |
| 2026-11-02 | M1 environment: section 4 rewritten to the real repo layout; T-015 (uv, just, ruff, pre-commit, CI). |
| 2026-11-02 | M0 governance: licence AGPL-3.0 (3.4, T-013), contribution workflow (T-014). |
| 2026-11-02 | Amended T-008 with T-012: offline VLM use allowed (X7, X8 in section 9). |
| 2026-11-02 | Added section 9, custom implementations and ablations (T-011); decision log, changelog and sources renumbered to 10 to 12. |
| 2026-11-02 | Renamed project to VBTSO (T-010). |
| 2026-10-20 | Added Hugging Face Hub (2.6, T-009); removed VLM pre-labelling from pipeline and sourcing (T-008). |
| 2026-10-20 | First version, from a full read of `main.ipynb`, `notebooks/01`, `notebooks/02`; external facts from web searches (YOLO26, dataset licences, SUMO benchmarks), several flagged *verify*. |

## 12. Sources consulted

- [Ultralytics YOLO26 page](https://www.ultralytics.com/yolo/yolo26) and [Roboflow YOLO26 model page](https://inference-models.roboflow.com/models/yolo26-object-detection/): NMS-free design, sizes, AGPL-3.0/Enterprise licensing.
- [UA-DETRAC paper](https://arxiv.org/pdf/1511.04136): fixed-camera detection and tracking benchmark.
- [RESCO benchmark](https://github.com/behradkoohy/RESCO): SUMO signal-control baselines and learning methods.
