# Review R5: AI engineering (export, serving, model use)

Status: **decided** (2026-11-02), defaults accepted (T-026).

## 1. Verdict

The spec lists five export formats (PyTorch, ONNX, OpenVINO, NCNN, TensorRT) for hardware we don't have. Benchmark only on what exists: **the Mac**. Run inference in the edge image **without Ultralytics or PyTorch**, through ONNX Runtime with our own pre- and post-processing.

## 2. Export and benchmark targets

| Format | Runs on | In scope | Why |
|---|---|---|---|
| PyTorch (MPS) | Mac | Yes, as the reference | Accuracy reference |
| **ONNX + ONNX Runtime (CPU)** | Mac, any Linux, edge image | **Yes, the deployment format** | Portable, already in the edge image |
| **Core ML** | Mac (Neural Engine) | Yes, optional | The fastest path on the actual hardware |
| ONNX INT8 (static quantisation) | Same as ONNX | Yes, as an experiment | Measures the accuracy cost of speed |
| OpenVINO | Intel CPUs | No | No Intel hardware |
| TensorRT | NVIDIA GPUs | No | No NVIDIA hardware |
| NCNN | Raspberry Pi / ARM | Later | Only when a hardware target exists |

Report for each format: mAP on the Rabat test set (the accuracy drop compared with PyTorch), latency p50/p95, FPS, and model size. The notebook's unsourced FPS claims (Raspberry Pi 10 to 14, Jetson 80+) are removed.

## 3. Serving design

- **Edge worker:** ONNX Runtime plus our own letterbox resize, input normalisation and output decoding. YOLO26 is NMS-free and its ONNX output is already final detections (legacy export: shape `(1, 300, 6)`), so decoding is short. This keeps the edge image small, avoids PyTorch and Ultralytics at runtime, and is a good piece of engineering to show.
- **Tracking at the edge:** our own tracker (X2) or a light standalone ByteTrack port. The Ultralytics tracker would pull in the whole package.
- **API:** stays a thin FastAPI service (R6). There is no model serving on the server side: the model runs only at the edge (privacy boundary R7).

## 4. Model use beyond the detector

- **VLM:** offline only, as decided in T-012. Grounding DINO or OWLv2 as the zero-shot baseline (X7), and a small open VLM run locally for rare-class label QA (X8). Check each model's licence before use.
- **No LLM in the runtime path.** An LLM-written traffic report or chat over the counts would be a stretch feature with no measurable value for signal timing, so it's not planned.

## 5. Demo

A Hugging Face Space (Gradio) that runs the ONNX model and the counter on a short clip, **after v1.0** (R1 cut list). The clip must be from a source whose licence allows public display (BMD-45 is CC BY; never the YouTube footage).

## 6. Decisions (default, override if you disagree)
1. Benchmark set: PyTorch-MPS, ONNX CPU, Core ML, ONNX INT8. Drop OpenVINO, TensorRT and NCNN from the spec until hardware exists.
2. Edge inference on ONNX Runtime without Ultralytics or PyTorch.
