# Review R3: Computer vision

Status: **decided** (2026-11-02): RF-DETR Nano replaces YOLO11n as comparison; count MAPE is the T2 metric (T-024).

## 1. Verdict

The model choice is right, and the evaluation protocol was the missing piece. Three changes:
- add an Apache-licensed detector as a comparison;
- define evaluation per class, per condition and on the held-out Rabat video;
- measure counting directly, because tracking scores don't measure counts.

## 2. Detector

| Model | COCO mAP50-95 | CPU ONNX latency | Licence | Source |
|---|---|---|---|---|
| YOLO11n | 39.5 | 56.1 ms | AGPL-3.0 | Ultralytics docs |
| **YOLO26n** | 40.9 (39.8 to 40.3 in end-to-end mode per arXiv overview) | **38.9 ms** (about 31% faster) | AGPL-3.0 | Ultralytics docs |
| **RF-DETR Nano** | 48.4 (vendor benchmark) | 2.32 ms on GPU (vendor) | **Apache-2.0** (Nano to Large) | Roboflow |

Recommendations:
- **Keep YOLO26n** as the default (T-003). It's NMS-free, so export and post-processing are simpler, and it's fastest on CPU, which matters for edge.
- **Replace the YOLO11n comparison with RF-DETR Nano.** YOLO11n adds little information. RF-DETR tells us whether a transformer detector is worth it here, and it is the **licence escape hatch** if AGPL ever becomes a problem (T-013). Its numbers are vendor-reported, so we reproduce them on our own data.
- Try the `s` size of the winner if latency on the Mac allows. Report latency next to accuracy, always.
- Transfer chain: COCO weights, then BMD-45, then Rabat. Use Ultralytics' `cls_remap` (maps classification-head rows by class name when fine-tuning across datasets, present in the current `default.yaml`).

## 3. Evaluation protocol

- **Splits:** BMD-45 by camera. The Rabat test set is the held-out video and is never trained on.
- **Metrics:** per-class AP50 and AP50-95, **with the box count next to each**. Confusion matrix (three-wheeler against motorcycle, and grand taxi against car, are the expected confusions). Breakdown by condition (day, night, rain).
- **Rare classes** (`tram`, `emergency`) are reported separately and never averaged into mAP.
- **Variance:** single runs for exploration, **3 seeds** for any number that goes into the README.
- **Experiment hygiene:** one factor changed per run (X4). Every run logs the dataset version (DVC hash) and the git commit (R4).

## 4. Tracking and counting

- **Trackers:** use the trackers built into Ultralytics. BoT-SORT scores 64.6 HOTA against 63.1 for ByteTrack on MOT17 (BoT-SORT paper), and has camera-motion compensation. Pick between them on our videos, not on MOT17.
- **Tracking metrics** (HOTA, IDF1 via TrackEval) need ground-truth tracks: UA-DETRAC once licensed, or CVAT tracks on a few clips.
- **Counting is the product metric:** count MAPE per counting line per 5-minute window against a manual count. No public source reports counting error for these trackers, so we measure it ourselves. Ground truth means counting by hand in CVAT on fixed-camera clips.
- **Counting method:** a line crossing by a confirmed track ID, with hysteresis (no double count when a box jitters on the line). Zones and lines are defined per camera in `configs/zones/<camera>.yaml`.
- **Queue estimate:** tracks inside an approach zone moving slower than a threshold (pixels/s) for longer than *t* seconds. It is uncalibrated in metres for now; adding a homography is a stretch item.

## 5. Known hard cases to test explicitly

Night glare and headlights, rain, occlusion by buses, three-wheelers against motorcycles, grand taxis against ordinary cars. Each one is a slice of the evaluation report.

## 6. Decisions requested
1. Swap the YOLO11n comparison for **RF-DETR Nano** (Apache-2.0) in P2.
2. Count MAPE as the T2 acceptance metric, with manual counts in CVAT as ground truth.

## Sources
- YOLO11 vs YOLO26, [Ultralytics docs](https://docs.ultralytics.com/compare/yolo11-vs-yolo26); YOLO overview, [arXiv 2510.09653](https://arxiv.org/pdf/2510.09653)
- RF-DETR licence and benchmarks (vendor), [PyPI](https://pypi.org/project/rfdetr/), [Roboflow blog](https://blog.roboflow.com/rf-detr-nano-small-medium/)
- BoT-SORT vs ByteTrack on MOT17, [arXiv 2206.14651](https://arxiv.org/pdf/2206.14651)
- Ultralytics `cfg/default.yaml` on GitHub `main` (fetched 2026-11-02): `cls_remap`, `cls_pw`
