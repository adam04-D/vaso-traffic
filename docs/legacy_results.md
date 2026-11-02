# Legacy results (hackathon notebooks)

Outputs that were saved inside `notebooks/01_data_engineering.ipynb` and `notebooks/02_model_training.ipynb`, kept here as a record before the pre-commit `nbstripout` hook removes notebook outputs. They come from the RamadnIA 2026 hackathon version (*GreenFlow Rabat*) and are the baseline the new pipeline has to be compared against. Not reproducible: the data lived on Google Drive and the exact split is unknown.

## Notebook 01: frame extraction and cleaning

Environment: Colab, Python 3.12.12, PyTorch 2.9.0+cu128, Tesla T4.

| Step | Result |
|---|---|
| Night video | 1457 MB, 30 FPS, 95,040 frames, 52.9 min; 1 frame every 5 s gave 638 frames |
| Filters | blur variance, mean brightness, perceptual-hash distance <= 4 (per-condition thresholds) |

| Condition | Start | Dark | Blur | Dupes | Kept |
|---|---:|---:|---:|---:|---:|
| Day | 523 | 0 | 1 | 1 | 521 |
| Night | 638 | 57 | 4 | 1 | 575 |
| Rain | 293 | 0 | 1 | 59 | 233 |
| **Total** | **1454** | | | | **1329** |

Thresholds: day blur < 50, dark < 20; night blur < 15, dark < 30; rain blur < 25, dark < 20.

## Notebook 02: dataset and training set-up

Roboflow export `CCTV.v9i.yolov8`. Splits: train 4406, valid 1259, test 629 images (frame-level, see technical spec 2.4).

| Item | Value |
|---|---|
| Annotated images | 1,088 |
| Empty images (negatives) | 5,206 |
| Total boxes | 7,914 |

| Class | Boxes | Share |
|---|---:|---:|
| Grand Taxi | 168 | 2.1% |
| Triporteur | 11 | 0.1% |
| bus | 190 | 2.4% |
| camion | 214 | 2.7% |
| moto | 203 | 2.6% |
| tram | 12 | 0.2% |
| urgence | 7 | 0.1% |
| voiture | 7,109 | 89.8% |

Largest class has 1016x more boxes than the smallest.

Model: `yolo26n.pt` (2,572,280 parameters, COCO pretrained), 8 classes.

Training config V1 (run name `greenflow_v1`): `imgsz` 640, `epochs` 100, `patience` 15, `batch` 16, AdamW, `lr0` 0.001, `lrf` 0.01, cosine LR, weight decay 0.0005, mosaic 1.0, mixup 0.15, copy_paste 0.3, hsv 0.015/0.7/0.4, degrees 5, translate 0.1, scale 0.5, fliplr 0.5.

**No final training metrics (mAP, precision, recall, per-class AP) were saved in the notebooks.** The confusion matrix and PR curve cells found no image files. Local inference on three test images printed "no detections". The first quantitative baseline therefore has to be re-measured on the new scene-level split (issue "baseline detector training with per-class metrics").

Export test (Windows, Ultralytics 8.4.21, CPU): `best.pt` 5.1 MB to `best.onnx` 9.4 MB, opset 12, 640x640 input, output shape (1, 300, 6).

## Notebooks 03 and 04, `main.ipynb`

`notebooks/03_traffic_logic.ipynb` and `notebooks/04_integration_main.ipynb` are empty. `main.ipynb` holds the v0 plan and the threshold-based edge script (see functional spec section 5).
