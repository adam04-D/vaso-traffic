# Functional Specification

> **Living document.** Every feature or technology decision updates the relevant section and appends a row to the [Changelog](#9-changelog) and [Decision log](#8-decision-log).
> Status tags: `[Current]` exists in the repo today · `[Critiqued]` reviewed and found weak · `[Proposed]` suggested, not agreed · `[Decided]` agreed with the owner.
> Companion document: [technical_spec.md](technical_spec.md).

**Working title:** *GreenFlow* → rename `[Proposed]` (candidates: *FlowSense*, *Intersect*, *Cadence*; decision pending, see [Open questions](#7-open-questions)).
**Owner:** Adam Daoudi · **Nature:** personal portfolio project (the RamadnIA 2026 hackathon is over).

---

## 1. Vision and goals `[Decided]`

Turn an ordinary fixed traffic camera into a traffic sensor, and use what it measures to advise signal timing at an intersection, with all image processing kept on the edge.

Because this is a portfolio project, there are two kinds of goals:

| Kind | Goal |
|---|---|
| Product | A pipeline that goes from video to counts to a signal-timing recommendation, validated in simulation. |
| Learning | Practise production-style data engineering (versioned data, reproducible pipelines), deep-network training (tracked experiments, imbalance handling, evaluation) and edge deployment (export, measured latency). |

The learning goals drive the design: when a simple shortcut hides the interesting part, we take the real route.

## 2. Context and scope

### 2.1 System context `[Proposed]`

```mermaid
flowchart LR
    CAM[Fixed traffic camera] -->|video stream| EDGE
    subgraph PRIV["Privacy boundary: raw images never leave"]
        EDGE[Edge device<br/>detect + track + count]
    end
    EDGE -->|"counts only (JSON)"| ORCH[Orchestration / API]
    ORCH --> DASH[Dashboard]
    ORCH --> CTRL[Signal-timing advisor]
    CTRL -->|advice, not control| OP[City traffic operator]
    DASH --> OP
```

The system is **advisory**: it recommends green times and never actuates a signal. This keeps the project safe and honest about what a portfolio project can claim.

### 2.2 Users `[Proposed]`

| User | Wants |
|---|---|
| Traffic engineer (target persona) | Counts per approach and a defensible timing recommendation. |
| ML practitioner / reviewer (real audience) | A reproducible repo, clear experiments, honest metrics. |

### 2.3 Capability tiers `[Proposed]`

Each tier has an acceptance metric. A tier is "done" only when its metric is measured, not when the code runs.

```mermaid
flowchart LR
    T1["T1 Perception<br/>detect + classify vehicles"] --> T2["T2 Estimation<br/>track, count per zone,<br/>queue length"]
    T2 --> T3["T3 Decision<br/>signal-timing advice"]
    T3 --> T4["T4 Integration<br/>API, dashboard"]
```

| Tier | Output | Acceptance metric (to be calibrated) |
|---|---|---|
| T1 Perception | Boxes + classes per frame | Per-class mAP50 on a **scene-held-out** test set; rare classes reported separately, not averaged away. |
| T2 Estimation | Vehicles crossing a line per interval; queue per approach | Count error vs. a manual count on held-out clips (target: ≤10% MAPE, to be revised after the first measurement). |
| T3 Decision | Green-time recommendation per phase | Average vehicle delay in simulation vs. a fixed-time baseline. |
| T4 Integration | Versioned JSON events, dashboard | Schema validated; end-to-end demo runs from a recorded video. |

### 2.4 Out of scope (for now)

Real signal actuation · multi-intersection coordination · deployment on a real city camera · license-plate reading (privacy, and not needed for counting) · field validation of the controller.

## 3. Domain strategy `[Proposed]`

The original project is Rabat-only, with classes such as *Grand Taxi* and *Triporteur*. That is a good hard case but a poor foundation: a recruiter cannot compare it with anything, and the data is too thin (see section 5).

**Decision proposed:** a city-agnostic core with a pluggable local-class layer.

```mermaid
flowchart TD
    ROOT[Vehicle taxonomy]
    ROOT --> CORE[Generic core: always trained]
    ROOT --> LOCAL[Local extension: per city]
    CORE --> car & bus & truck & motorcycle & bicycle
    CORE --> special[emergency vehicle / tram]
    LOCAL --> RBT[Rabat]
    RBT --> GT[grand taxi]
    RBT --> TRI[triporteur]
```

- Generic classes are trained on large public data, so metrics are comparable with published results.
- Rabat classes are the **flagship stress test**: few samples, visually specific, so they exercise few-shot and imbalance techniques.
- Open question: is `tram`/`emergency` core or local? (They are rare everywhere.)

## 4. Control problem `[Proposed]`

The original plan called this an "optimal transport problem". Reviewing it: what we are solving is **traffic-signal control**, a queueing and flow-optimisation problem (choose phases and green durations to minimise delay or maximise throughput). Optimal transport in the Wasserstein sense would only apply to adjacent sub-problems (origin-destination estimation, or measuring domain shift between cities). We will not use the term for the controller unless a real OT component is added.

Tiered, so we always have a working baseline to beat:

| Tier | Method | Why |
|---|---|---|
| C0 | Fixed-time plan | The baseline everything is compared to. |
| C1 | Webster's formula / queue-proportional split | Classical, analytic, explainable. |
| C2 | Max-pressure | Strong, decentralised, needs only queue counts. In published SUMO benchmarks it is hard for learning methods to beat. |
| C3 (optional) | Reinforcement learning in SUMO | Learning showcase; only worth it if it is compared fairly against C2. |

The current heuristic (`main.ipynb`: ≥15 vehicles → 90 s green, ≥7.5 → 45 s, else 20 s) is C−1: arbitrary thresholds, no link to demand or to the other approaches `[Critiqued]`.

## 5. Piece-by-piece critique of the current state `[Critiqued]`

Maturity: 1 = idea, 5 = production-grade.

| Component | What exists | Maturity | Main problems |
|---|---|---|---|
| Data sourcing | Frames from 3 YouTube drive-through videos (day, night, rain) | 2 | Driving footage is not a fixed-camera view; licence/privacy unclear; every frame of a video is highly correlated. |
| Data storage | Google Drive, hardcoded paths, Colab mounts | 1 | Not reproducible, no versioning, tied to one vendor. |
| Dataset quality | 6,294 images in splits, only 1,088 annotated, 7,914 boxes | 2 | 89.8% `voiture`; `urgence` 7, `Triporteur` 11, `tram` 12 boxes; 5,206 empty images; frame-level splits probably leak. |
| Model | YOLO26n, 8 classes, Colab/Kaggle | 2 | No final metrics saved; V2 notes mention `image_weights`/`fl_gamma` that are not in the training config; the notebook says YOLO11n elsewhere. |
| Edge runtime | Script in `main.ipynb` | 1 | Counts boxes per frame (not flow); no tracking; fixed thresholds; "QUEUED" message but no queue; example RTSP URL with credentials. |
| Control logic | Threshold rules | 1 | See section 4. |
| Integration | n8n webhook payload | 1 | Ad-hoc schema, unversioned. |
| Repo hygiene | 3 notebooks, rest empty | 1 | Empty README/configs/train.py; incomplete `requirements.txt`. |

```mermaid
quadrantChart
    title Fix priority (risk vs. effort)
    x-axis Low effort --> High effort
    y-axis Low risk --> High risk
    quadrant-1 Plan carefully
    quadrant-2 Do first
    quadrant-3 Quick wins
    quadrant-4 Defer
    Data storage: [0.25, 0.7]
    Split leakage: [0.3, 0.85]
    Data sourcing: [0.75, 0.9]
    Edge tracking and counting: [0.55, 0.8]
    Control validation: [0.7, 0.75]
    Repo hygiene: [0.15, 0.3]
    Rename: [0.1, 0.1]
    RL controller: [0.9, 0.35]
```

## 6. Roadmap `[Proposed]`

```mermaid
gantt
    dateFormat  YYYY-MM-DD
    title Phases (durations indicative)
    section MVP
    Spec + repo restructure       :a1, 2026-10-20, 7d
    Data pipeline + versioning    :a2, after a1, 14d
    Baseline detector + metrics   :a3, after a2, 14d
    Tracking + zone counting      :a4, after a3, 14d
    section Decision
    SUMO sim + C0/C1/C2           :b1, after a4, 21d
    section Later
    Edge benchmarks, dashboard    :c1, after b1, 14d
    RL controller (optional)      :c2, after c1, 21d
```

**MVP** = recorded video in, per-zone counts out, validated against manual counts, with a simulated baseline comparison started.
**Not now:** RL, multi-intersection, real-camera deployment, mobile apps.

## 7. Open questions

1. Final project name.
2. Are `tram` and `urgence` core or local classes?
3. Which public datasets pass the licence check (see technical_spec section 2.3)?
4. Do we have access to any fixed-camera footage of Rabat (public webcams, or our own recording)?
5. Which Rabat intersection becomes the simulated case study?
6. Licence of this repo (see AGPL risk in technical_spec section 3.4).

## 8. Decision log

| ID | Date | Decision | Status | Rationale |
|---|---|---|---|---|
| D-001 | 2026-10-20 | Personal portfolio project, no longer a hackathon | Decided | Owner. |
| D-002 | 2026-10-20 | Specs in English | Decided | Public portfolio. |
| D-003 | 2026-10-20 | Generic core, Rabat as flagship case | Decided | Comparable metrics, plus a hard local test. |
| D-004 | 2026-10-20 | Free/low-cost compute, object storage + DVC instead of Drive | Decided | Reproducibility, real data-engineering practice. |
| D-005 | 2026-10-20 | Tiered control: fixed-time → Webster/max-pressure → optional RL in SUMO | Decided | Always keep a baseline to beat. |
| D-007 | 2026-10-20 | Publish datasets/weights on Hugging Face Hub; no VLM pre-labelling or judge-model evaluation | Decided | Portfolio visibility without extra complexity. |
| D-006 | 2026-10-20 | System is advisory only | Proposed | Safety and honesty of claims. |

## 9. Changelog

| Date | Change |
|---|---|
| 2026-10-20 | Added D-007 (Hugging Face Hub; VLM rejected). |
| 2026-10-20 | First version: vision, tiers, domain strategy, control problem, critique, roadmap. |
