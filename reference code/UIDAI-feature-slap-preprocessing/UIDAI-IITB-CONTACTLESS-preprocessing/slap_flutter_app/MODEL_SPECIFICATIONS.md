# YellowSense UIDAI — Model Specifications
**Project:** SU-C1-2025-02 · YellowSense Technologies · SITAA Cohort 1  
**Backend:** Flask (Python 3.11) + PyTorch + TensorFlow  
**Provided by:** IIT Bombay Contactless Fingerprint Team

---

## Summary Table

| # | File | Task | Architecture | Parameters | File Size |
|---|------|------|-------------|-----------|-----------|
| 1 | `best-new.pt` | Finger Detection + Segmentation | YOLOv8n-seg | 3.26M | 6.4 MB |
| 2 | `best_f1.pth` | Minutiae Extraction | Custom MinutiaeNet (Hourglass) | 8.76M | 100 MB |
| 3 | `liveness_model_v3.pt` | Liveness Detection (anti-spoof) | MobileNetV2 + custom head | 2.55M | 10 MB |
| 4 | `u2net_320x320_float32.tflite` | Finger Foreground Segmentation | U²Net (TFLite) | — | 4.0 MB |
| 5 | `zero_dce_model.h5` | Low-light Image Enhancement | Zero-DCE (DCENet) | — | 966 KB |
| 6 | `bright_spot_detection.pt` | Glare / Bright-spot Detection | YOLOv8s | 11.1M | 21 MB |
| 7 | `best_float32.tflite` | Finger Coverage Mask | TFLite (coverage) | — | 43 MB |
| 8 | `hand_landmarker.task` | Gesture Liveness (finger count) | MediaPipe Hand Landmarker | — | — |

---

## 1. Finger Detector — `best-new.pt`

| Property | Value |
|----------|-------|
| **Task** | Instance segmentation (used as object detection — bbox crop) |
| **Base architecture** | YOLOv8n-seg (nano segmentation variant) |
| **Framework** | Ultralytics YOLOv8 v8.4.41 |
| **Trainable parameters** | 3,263,811 (~3.3M) |
| **Input size** | 640×640 (inference at 800px) |
| **Training data** | Custom fingerprint dataset (`fingertip_segmentation.yolov8-obb`) stored on Google Drive |
| **Training config** | 100 epochs, batch 16, SGD → auto optimizer, AMP, imgsz 640 |
| **Validation metrics** | mAP50(B)=0.995 · mAP50-95(B)=0.891 · Precision=0.9997 · Recall=1.0 |
| **Segmentation metrics** | mAP50(M)=0.995 · mAP50-95(M)=0.893 |
| **Use in pipeline** | Step 1 — detect finger region, extract bounding box, crop image for downstream processing |
| **Inference call** | `YOLO('best-new.pt', task='detect')(img, imgsz=800, conf=0.1)` |

**Notes:** Model is fine-tuned from `yolov8n-seg.pt` (ImageNet pretrained backbone). Despite being a segmentation model internally, we use only the bounding box output for cropping. Detection confidence threshold is set low (0.1) to maximise recall on partially visible fingers.

---

## 2. MinutiaeNet — `best_f1.pth`

| Property | Value |
|----------|-------|
| **Task** | Fingerprint minutiae detection (location + direction + type) |
| **Architecture** | Custom **MinutiaeNet** — Hourglass encoder-decoder with SE-ResBlocks + Attention |
| **Framework** | PyTorch |
| **Total parameters** | 8,759,880 (~8.76M) |
| **Input** | 256×256 grayscale, normalised [0,1] |
| **Outputs** | 4 maps — location heatmap, cos(θ), sin(θ), type (RIG/BIF) |
| **Base channels** | 64 |
| **Hourglass depth** | 3 levels |
| **Training config** | Adam, lr=0.001, batch=4, ReduceLROnPlateau (patience=5, factor=0.5) |
| **Training epochs** | 4992 steps (lr decayed to 0.000125) |
| **Validation metrics** | F1=0.710 · Precision=0.722 · Recall=0.699 · Type acc=0.814 |
| **Minutiae direction accuracy** | 90.87% within 20° tolerance |
| **Use in pipeline** | Step 5 — extract minutiae points (x, y, direction, type) for MCC matching |
| **Inference call** | `model(tensor_256x256)` → 4 output maps, NMS at threshold=0.3, nms_size=5 |

**Architecture detail:**
```
Input (1×256×256)
  → InitialConv (1→64, 7×7)
  → ResBlock1 (64→64)  → Downsample (/2)
  → ResBlock2 (64→64)  → Downsample (/2)
  → HourglassModule (depth=3, SE-ResBlocks + PixelShuffle upsampling)
  → LocationHead   → sigmoid → heatmap
  → AttentionModule → DirectionHead → tanh → (cos,sin) normalised
  → TypeHead → sigmoid → RIG/BIF probability
```

---

## 3. Liveness Model — `liveness_model_v3.pt`

| Property | Value |
|----------|-------|
| **Task** | Binary classification — Live finger vs Spoof/Fake |
| **Architecture** | **MobileNetV2** backbone + custom classifier head |
| **Framework** | PyTorch · torchvision |
| **Total parameters** | 2,552,322 (~2.55M) |
| **Classifier head** | `Dropout(0.2) → Linear(1280→256) → ReLU → Dropout(0.2) → Linear(256→2)` |
| **Input** | 224×224 RGB, ImageNet normalisation (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225]) |
| **Output** | Softmax probabilities [live_prob, spoof_prob] |
| **Decision threshold** | **0.3** (live_prob ≥ 0.3 → LIVE) |
| **Training data** | Live: YOLO-cropped RGB fingerprints · Spoof: HDA ColFIS Spoof dataset |
| **Validation AUC** | **1.0** |
| **FAR** | **0.0** (zero false accepts) |
| **FRR** | **0.0081** (0.81% false rejects) |
| **Use in pipeline** | Step 2 — reject spoofed or printed fingerprints before enrollment/auth |
| **Inference call** | `F.softmax(model(tensor_224x224), dim=1)[0,0]` → live probability |

---

## 4. U²Net Segmentation — `u2net_320x320_float32.tflite`

| Property | Value |
|----------|-------|
| **Task** | Salient object detection / foreground segmentation of finger |
| **Architecture** | **U²Net** (U-square Net) — nested U-structure with RSU blocks |
| **Framework** | TensorFlow Lite (float32) |
| **Input** | 320×320×3 RGB, normalised [0,1] |
| **Output** | 320×320×1 probability mask |
| **Threshold** | 0.3 (binary mask) |
| **File size** | 4.0 MB |
| **Paper** | U²Net: Going Deeper with Nested U-Structure for Salient Object Detection (CVPR 2020) |
| **Use in pipeline** | Step 3a — generate foreground mask, isolate finger from background, white-fill background |
| **Post-processing** | Convex hull of largest contour → clean mask, central ROI erosion |

---

## 5. Zero-DCE Enhancement — `zero_dce_model.h5`

| Property | Value |
|----------|-------|
| **Task** | Low-light / under-exposed image enhancement |
| **Architecture** | **Zero-DCE** (Zero-Reference Deep Curve Estimation) — DCENet |
| **Framework** | Keras / TensorFlow (.h5) |
| **Input** | Any resolution RGB, normalised [0,1] |
| **Output** | Enhanced RGB image, same resolution |
| **DCE net structure** | 7 Conv2D layers (32 filters, 3×3, ReLU) + skip connections → 24-channel tanh output (8 enhancement curves × RGB) |
| **File size** | 966 KB |
| **Paper** | Zero-Reference Deep Curve Estimation for Low-Light Image Enhancement (CVPR 2020) |
| **Use in pipeline** | Step 3b — applied only when mean luminance of cropped finger < 150. Falls back to histogram equalisation otherwise |
| **Enhancement formula** | `x_enhanced = x + A·(x² - x)` iterated 8 times |

---

## 6. Bright-spot / Glare Detector — `bright_spot_detection.pt`

| Property | Value |
|----------|-------|
| **Task** | Object detection — detect glare / over-exposed bright spots in fingerprint image |
| **Architecture** | **YOLOv8s** (small variant) |
| **Framework** | Ultralytics YOLOv8 v8.2.103 |
| **Total parameters** | 11,135,987 (~11.1M) |
| **Input size** | 800×800 |
| **Training data** | Custom Bright-spot detection dataset (Roboflow) |
| **Training config** | 25 epochs, batch 16, imgsz 800 |
| **Validation metrics** | mAP50=0.649 · Precision=0.496 · Recall=0.65 |
| **Use in pipeline** | Quality gate — if any bright-spot box detected → `has_glare=True` → guidance: "Glare detected — adjust angle" |
| **Fallback** | If model unavailable: pixel threshold — overexposed fraction > 5% of image area |

**Note:** mAP is moderate (0.649) — this is expected for glare detection which is highly dependent on lighting conditions. The pixel fallback ensures robustness.

---

## 7. Coverage Mask — `best_float32.tflite` + `coverage_mask.tflite`

| Property | Value |
|----------|-------|
| **Task** | Finger coverage / area mask (backup/alternative to U²Net) |
| **Framework** | TensorFlow Lite (float32) |
| **File size** | 43 MB each |
| **Use in pipeline** | Currently loaded but not actively used in primary pipeline (U²Net is primary). Available as fallback coverage estimator |

---

## 8. MediaPipe Hand Landmarker — `hand_landmarker.task`

| Property | Value |
|----------|-------|
| **Task** | Hand landmark detection — 21 keypoints per hand |
| **Architecture** | MediaPipe Hand Landmarker (BlazePalm + Hand Landmark model) |
| **Framework** | MediaPipe Tasks Python API (v0.10+) |
| **Input** | Any resolution RGB image |
| **Output** | 21 3D landmarks per hand (normalised coordinates) |
| **Use in pipeline** | `/liveness_gesture` endpoint — count extended fingers for gesture challenge (finger tip.y < pip.y = extended) |
| **Finger detection logic** | Thumb: tip.x < pip.x → extended. Fingers 2–5: tip.y < pip.y → extended |
| **Availability** | Optional — endpoint returns 501 if `.task` file missing |

---

## Matching Algorithm — MCC + Relaxation Labeling (no separate weight file)

| Property | Value |
|----------|-------|
| **Algorithm** | Minutiae Cylinder-Code (MCC) graph + Relaxation Labeling |
| **Input** | Two lists of minutiae (x, y, direction, type) |
| **Graph construction** | K=6 nearest neighbours per minutia, edge = (distance bin, angle bin, orientation delta) |
| **Bins** | Distance: 15px bins · Angle: 16 bins (2π) · Orientation: 16 bins |
| **Relaxation iterations** | 10 |
| **Matching score** | `2 × matches / (|T1| + |T2|) × size_ratio` → [0, 1] |
| **Decision threshold** | **0.25** (enroll/verify/authenticate) |
| **Pre-processing** | Template normalised (zero-centred) + scaled to 200px span |

---

## Pipeline Flow (end-to-end)

```
Camera Image
     │
     ▼
[1] best-new.pt        YOLOv8n-seg   → Detect & crop finger region
     │
     ▼
[2] liveness_model_v3.pt  MobileNetV2 → Live / Spoof classification
     │  (reject if spoof)
     ▼
[3a] u2net_320x320.tflite  U²Net      → Foreground segmentation mask
[3b] zero_dce_model.h5     Zero-DCE   → Low-light enhancement (conditional)
     │
     ▼
[4] Adaptive threshold + Gabor ROI   → Binary ridge image (no ML)
     │
     ▼
[5] best_f1.pth  MinutiaeNet         → Minutiae: {x, y, θ, type}
     │
     ▼
[6] MCC + Relaxation Labeling        → Matching score [0,1]
     │
     ▼
   Decision (threshold 0.25)

Quality Gate (runs in parallel with steps 1-3):
  • check_blur()       → Laplacian variance
  • check_brightness() → Mean luminance
  • check_glare()      → bright_spot_detection.pt / pixel fallback

Readiness Score (runs independently via /readiness):
  • blur_norm×30 + brightness_norm×25 + glare_norm×20 + minutiae_norm×25

Gesture Liveness (runs via /liveness_gesture):
  • hand_landmarker.task  → count extended fingers → challenge match
```

---

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 4 GB | 8 GB |
| GPU | Not required (CPU inference) | CUDA GPU (10× speedup) |
| Storage | 200 MB (model files) | 500 MB |
| Python | 3.11 | 3.11 |
| PyTorch | ≥2.1.0 | 2.3.x |
| TensorFlow | 2.16.2 | 2.16.2 |

**End-to-end inference time (CPU, 1 image):**
- Quality gate: ~0.3s
- Full pipeline (detect → liveness → segment → enhance → minutiae): ~3–5s
- Matching (per template pair): <0.1s

---

*YellowSense Technologies · SITAA Cohort 1 · 2025*
