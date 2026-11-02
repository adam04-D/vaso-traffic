# Review R1: Idea and scope

Status: **decided** (2026-11-02): MVP, cut list and claims policy approved (functional D-010, technical T-023).

## 1. Verdict

The idea holds up as a portfolio project: one pipeline from video to counts to signal-timing advice, measured at every step. Two things need correcting.
- **Breadth, not depth, is the main risk.** Data engineering, detection, tracking, control, MLOps and serving are each a project on their own, for one person on free compute.
- **The link between perception and control is the weakest claim.** The Rabat footage is filmed from a moving car, so it can't measure queues at an intersection. The controller can only be validated in simulation, with sensing noise taken from what perception achieves. That is honest, as long as it is said.

## 2. Is the problem worth solving?

- Camera-based traffic counting is a solved commercial product (Miovision, for example), and adaptive signal control is a mature field. The project doesn't invent either.
- What it can credibly show is:
  1. an **open, reproducible, measured** pipeline end to end;
  2. **domain adaptation** to North-African and developing-city traffic (three-wheelers, grand taxis), which public benchmarks cover poorly;
  3. **how perception error propagates into control quality**, which is rarely quantified.

Point 3 is the most original part, and the specs already contain it (technical 6.2, "noisy sensing").

## 3. MVP, redefined

**MVP = v1.0 release**, all four parts measured:

| Tier | MVP content | Acceptance metric |
|---|---|---|
| T1 Perception | YOLO26n trained COCO, then BMD-45, then Rabat fine-tune | Per-class AP50 with box counts on the **held-out Rabat video**, reported for each step (X6 a to c) |
| T2 Estimation | Tracking + line/zone counting | Count MAPE ≤ 10% per line per 5-min window on **fixed-camera public video** (MoVITS if fixed, else UA-DETRAC once licensed) |
| T3 Decision | C0 Webster-tuned fixed-time, C1 queue-proportional, C2 max-pressure, in SUMO | Mean delay vs C0, over 4 demand levels and 10 seeds, with **ideal and noisy sensing** |
| T4 Integration | Edge worker → FastAPI → `/advice` endpoint, run on a recorded video | Schema-valid events end to end, in `docker compose` |

**Cut from the MVP (stretch, after v1.0):** RL controller (X5), mini detector (X1), dashboard, multi-intersection, real camera or hardware, Hugging Face Space demo.
**Kept as cheap experiments inside the MVP:** X3 (imbalance), X4 (ablations), X6 (domain shift), X7 (zero-shot baseline). X2 (own tracker) and X8 (VLM label QA) only if time allows.

## 4. Claims (what the README may say)

- "Advisory signal-timing recommendations, validated in simulation (SUMO). Never actuates a signal."
- "Detector trained on developing-city fixed CCTV (BMD-45), fine-tuned and evaluated on Rabat street footage."
- **Not allowed:** "deployed", "real-time city system", "validated on Rabat cameras", "reduces congestion by X%" (only "in simulation, under these assumptions").

## 5. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Scope creep across six disciplines | High | High | MVP above, stretch list, time-box per P milestone; cut stretch items first |
| Free GPU quota (Kaggle weekly limit, *verify current hours*) | Medium | Medium | YOLO26n/s only, small ablations, Mac MPS for smoke runs, cache datasets |
| Licence of a source turns out restrictive | Medium | Medium | Catalogue per-image licence (T-019); release rules (T-022) |
| Rabat test set too small (3 videos) | High | Medium | Find more videos (P1 issue); report confidence intervals, not single numbers |
| No fixed-camera counting ground truth | Medium | High | MoVITS check first in P1; UA-DETRAC licence; label counts in CVAT if needed |
| SUMO learning curve | Medium | Medium | Start from sumo-rl/RESCO single-intersection nets before the Rabat junction |
| Network instability to GitHub/registries | High (observed) | Low | Retries in scripts, pinned images, cached builds |
| Solo maintainer time | High | High | One issue at a time, small PRs, stop at v1.0 |

## 6. Decisions requested
1. Approve the MVP and cut list in section 3.
2. Approve the claims policy in section 4. It goes into the README and model cards.
