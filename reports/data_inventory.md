# Data inventory (D1, step 0)

What data exists, where it is, whether it may be used, and in what state. It was written on 2026-11-18, after a snapshot of the old Google Drive folder was taken. The registry of all sources is [`configs/sources.yaml`](../configs/sources.yaml).

## 1. Where the data was

| Location | Content | Outcome |
|---|---|---|
| Google Drive `GreenFlow-Rabat/` | Frames, quality-filter output, Roboflow exports, `CCTV.v9`, `dataset.zip` | **Copied** to `data/raw/greenflow_drive/` with `rclone copy`. `rclone check` verified it: 25,565 files, 1.9 GB. |
| Roboflow, workspace `adams-space-eu9h9` | Two projects: `greenflow-rabat-` (6,294 images) and `GreenFlow Rabat` (4,592) | Master copy of the labels. **Both are public**: make them private or remove them. |
| Kaggle `adamdaoudi04/greenflow`, `adamdaoudi04/maroc-data` | Copies of the Roboflow exports v4 and v7 | Private. Duplicates, so they aren't needed. |
| This Mac | Nothing | – |
| The 3 YouTube videos | Not found anywhere | Lost. The source channel is very likely **STREET.MA** (its title appears on the night frames). The night video id is `aFtBUlb9yj8`. |

## 2. The snapshot: `data/raw/greenflow_drive/`

| Folder | Files | Content |
|---|---:|---|
| `Extracted_Frames/` | 1,454 | Every frame taken from the 3 videos, 1920×1080 |
| `kept_frames/{day,night,rain}` | 521 / 560 / 227 = **1,308** | Frames that passed the quality filters |
| `rejected_frames/{day,night,rain}` | 2 / 76 / 66 = 144 | Dark, blurry or duplicate frames |
| `train/` `valid/` `test/` | 4,406 / 1,259 / 629 = 6,294 images + labels | Merged Roboflow export (`greenflow-rabat-iuq8w` v4), 640×640 |
| `CCTV.v9i.yolov8/` | 5,032 images + labels | Roboflow Universe `nyc/cctv-kqokl` v9 |
| `dataset.zip` | 336 MB | Duplicate of `train/valid/test` |

## 3. Checks and verdicts

| # | Check | Result | Verdict |
|---|---|---|---|
| 1 | Classes | 8: `Grand Taxi, Triporteur, bus, camion, moto, tram, urgence, voiture` (ids 0–7) | ✅ |
| 2 | Counts | Every split has as many label files as images | ✅ |
| 3 | File types | jpg, txt, yaml, one zip | ✅ The zip is a duplicate |
| 4 | Sources in the export | **Rabat 1,308** (all `kept_frames`, no more and no less). **Others 4,986**: screenshots, WhatsApp images, ImageNet, press photos | ⚠️ Mixed |
| 5 | Label format | `class xc yc w h`, normalised | ✅ |
| 6 | Empty labels | Rabat 224 / 1,308 (17%). **Others 4,982 / 4,986 (99.9%)** | 🔴 The web images lost their labels |
| 7 | Classes (Rabat) | voiture 6,165 · camion 196 · moto 190 · Grand Taxi 140 · bus 114 · tram 9 · Triporteur 6 · urgence 6 | 🔴 90% cars; 3 classes have fewer than 10 boxes |
| 8 | Boxes per image | Max 29, total 6,825 (Rabat) | ✅ |
| 9 | Image size | Originals 1920×1080. Export **640×640, stretched** | 🔴 The aspect ratio is distorted |
| 10 | Exact duplicates (md5) | 0 | ✅ |
| 11 | Augmented copies | Non-Rabat images appear up to 6 times, and the same source image is in more than one split (train∩valid 677, valid∩test 173) | 🔴 Leakage, in the discarded part |
| 12 | Rabat split | No copies, no names shared across splits, but each split mixes all 3 videos | ⚠️ Frame-level split, so neighbouring frames leak |
| 13 | `CCTV.v9` origin | Roboflow Universe `nyc/cctv-kqokl` v9, CC BY 4.0, 7 classes, nearly all labelled | ✅ Origin and licence found |

## 4. Two investigations

**Two frames are in neither the kept nor the rejected folder.** `rabat_night_0001` and `rabat_night_0637` both show the large **"STREET.MA"** title, the intro and the end of the night video. They were removed by hand, which was correct, because text overlays mislead the model.

**1,308 frames are kept, not 1,329 as the notebook says.**

| Condition | Extracted | Kept (notebook) | Kept (Drive) | Rejected (Drive) |
|---|---:|---:|---:|---:|
| Day | 523 | 521 | 521 | 2 |
| Night | 638 | 575 | 560 | 76 (+2 title frames) |
| Rain | 293 | 233 | 227 | 66 |
| Total | 1,454 | 1,329 | **1,308** | 144 |

The gap comes from night (−15) and rain (−6). Those frames moved to `rejected_frames`, so the filters were rerun or the frames were reviewed by hand after the notebook outputs were saved. The notebook table is also off by one (57 + 4 + 1 = 62 rejected gives 576 kept, not 575).

**Conclusion:** the Drive folders are the source of truth, and the old notebook outputs are stale. The 1,308 kept frames match the 1,308 labelled Rabat images exactly.

## 5. Decisions

1. **Keep the Rabat set:** 1,308 images and their labels. Status: research-only (third-party YouTube footage, never redistributed). It is the Moroccan anchor and holds the only test set that matters.
2. **Use the 1920×1080 originals** from `kept_frames/` with the existing labels. YOLO coordinates are normalised, so they transfer without changes. Resize at training time, keeping the aspect ratio.
3. **Re-split by video:** 2 videos for fine-tuning, 1 held out for testing, never mixed.
4. **Discard the 4,986 non-Rabat images** of the merged export. Their labels are lost, so they would teach the model that vehicles are background.
5. **Keep `CCTV.v9`** as a possible extra base source (CC BY 4.0, labelled). Remove its augmented copies before using it.
6. **Base dataset:** to be chosen by measurement (BMD-45 vs a dashcam dataset vs COCO only) on the held-out Rabat video, in D3.
7. **Moroccan additions:** MoVITS (pending, since Mendeley is down) and a labelled Mapillary sample.

## 6. Open items

- [ ] Find the 3 STREET.MA video URLs and fill them into `configs/sources.yaml`.
- [ ] Make both Roboflow projects private, or remove them after export.
- [ ] Confirm the `CCTV.v9` licence on its Universe page.
- [ ] Retry the MoVITS download, then check its licence, format, labels and viewpoint.
- [ ] Put `data/raw/greenflow_drive` under DVC and push it to R2 (step 3).

## 7. Lessons

- The same data existed in four copies (Drive, zip, Kaggle, Roboflow), and none of them was clearly the reference. Versioned storage (DVC) fixes that.
- A tool's licence field (Roboflow "CC BY 4.0") only says what someone selected. It doesn't make third-party images free to use.
- Saved notebook outputs go stale as soon as a step is rerun by hand. Counts must come from the data itself.
- Stretching to a square silently changes object shapes. Keep originals, and resize at training time.
- Class ids start at 0. An off-by-one shift in the class mapping went unnoticed during this inventory until the counts were checked by hand.
