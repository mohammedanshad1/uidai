# Multi-Finger (Slap) Contactless Fingerprint Pipeline

A **new, self-contained** multi-finger pipeline built in this folder. It does
**not** modify `uidai_app`. It reuses the *proven* single-finger logic (copied
faithfully into `slap_core.py`) and removes the single-finger bottleneck so all
detected fingers are captured, preprocessed, and turned into ISO 19794-2
templates.

```
slap_app.py     Flask service: /process_slap, /enroll_slap, /health
slap_core.py    Self-contained model defs + per-finger pipeline (no uidai_app dep)
models/         Copied weights: best-new.pt, u2net, zero_dce, best_f1.pth, liveness
test_slap.py    CLI smoke test against a running server
MultiFingerYOLOAnalyzer.kt   On-device variant of the fix (formulas untouched)
requirements.txt
```

---

## 1. Strategic Review (what we're fixing)

The production `uidai_app` is **Flutter UI → Python Flask backend**
(`backend/app_5003.py`, the deployed `:5003` server). The on-device `.kt` files
you also shared are a *separate, older* native-Android prototype. Both share one
flaw:

| Issue | Where | Fix |
|---|---|---|
| **Single-finger by `argmax`** — the detector finds all fingers, then keeps only the highest-confidence one | `backend/app_5003.py:621` (`np.argmax`); also `:1308`, `:1413`; on-device `yolo-analyzer.kt:47` (`processedBitmap[0]`) | Loop all boxes → `detect_all_finger_boxes()` |
| **Crop crash on edge fingers** — `Bitmap.createBitmap` / array slice throws when a box touches the frame edge | `yolo-analyzer.kt drawDetectionResult` (no clamp) | Clamp crop to bounds (formulas untouched) |
| **1-template-per-user schema** — `UNIQUE(uid,batch)`, 1:1 matching | backend DB + `match_templates` | New `slap_templates` table keyed by `(uid,batch,finger_position)` |
| **SAM ViT-H preprocessing is undeployable** (2.4 GB) — only in the `Untitled36.ipynb` research notebook | notebook | Dropped. Backend already uses U2-Net (4 MB) — we reuse that |
| **Dead weight** — `best_float32.tflite`, `coverage_mask.tflite` loaded-but-unused | backend | Not carried forward |
| On-device only: tflite never closed, per-frame byte boxing in `LuminosityAnalyzer`, bitmap leaks, `byte[]` Intent extra → `TransactionTooLargeException` | `MainActivity.kt` | Recycle bitmaps, pass file paths, close interpreter (see `.kt` notes) |

**Key insight:** minutiae extraction + ISO export already exist and work
(`MinutiaeNet` + `export_iso_template`). We did **not** rebuild them — we loop
them over N fingers.

---

## 2. Integration Plan — removing the single-index limit

**Backend (chosen path).** The only algorithmic change is detection. In
`slap_core.detect_all_finger_boxes()` the original:

```python
best = int(np.argmax(confs))     # keep ONE finger
x1, y1, x2, y2 = map(int, boxes[best])
```

becomes a loop over every box (NMS is already applied by YOLO), clamped to
bounds and sorted left→right. Everything downstream
(`preprocess_fingerprint` → `detect_minutiae` → `export_iso_template`) is the
proven code, called once per finger in `process_one_finger()`.

**On-device (`MultiFingerYOLOAnalyzer.kt`, optional).** The bounding-box
formulas in `interpretResults()` are copied **verbatim** (the
`(x - w/2)*b …` block is fenced with a DO-NOT-ALTER comment). Only two things
change: the callback becomes `(List<Bitmap>, List<DetectionResult>)`, and
`drawDetectionResult()` clamps each crop. The corresponding `MainActivity`
change is to iterate the returned list:

```kotlin
val analyzer = MultiFingerYOLOAnalyzer(tflite) { crops, results ->
    crops.forEachIndexed { i, crop ->
        // upload each crop, or save to filesDir and pass the PATH (not bytes)
        // to the next Activity to avoid TransactionTooLargeException.
    }
}
```

---

## 3. Pipeline Architecture

```
        slap image (one photo of 4 fingers)
                     │
   ┌─────────────────▼──────────────────┐
   │ STAGE 1  YOLO detect ALL fingers    │  best-new.pt (Ultralytics)
   │          → N boxes, L→R, labelled   │  detect_all_finger_boxes()
   └─────────────────┬──────────────────┘
        per finger ──┤  (loop)
   ┌─────────────────▼──────────────────┐
   │ liveness   MobileNetV2              │  check_liveness()
   │ STAGE 2  segment  U2-Net (4 MB)     │  get_segmentation_mask()
   │          enhance  Zero-DCE / hist-eq│  preprocess_fingerprint()
   │          binarize adaptive threshold│
   │ STAGE 3  minutiae MinutiaeNet       │  detect_minutiae()
   │ STAGE 4  template ISO 19794-2 FMR   │  export_iso_template()
   └─────────────────┬──────────────────┘
                     ▼
        per-finger templates + minutiae (JSON)
```

**Libraries/tools** (same proven stack): `ultralytics` (YOLO), `tensorflow`
(U2-Net TFLite + Zero-DCE Keras), `torch`/`torchvision` (MinutiaeNet, liveness),
`opencv-python`, `scipy`. No new heavy dependency was introduced.

---

## 4. Step-by-Step Roadmap

1. **Stand up the service (done).** `python slap_app.py` → verify
   `GET /health` lists `finger_detector, u2net, minutiae, liveness`.
2. **Validate detection** on a real slap image: `python test_slap.py slap.jpg right`.
   Confirm `finger_count` matches the fingers presented and labels read
   left→right.
3. **Tune `finger_order` / `hand_side`.** Slap labelling is orientation
   dependent — confirm the default L→R map against your capture geometry; pass a
   custom `finger_order` form field if needed.
4. **Per-finger quality gate.** Reuse the backend's blur/brightness/glare gate
   per crop; reject low-quality fingers individually instead of the whole hand.
5. **Wire the Flutter UI** to `multipart POST /enroll_slap` (one call, N
   templates back). Widen the capture oval overlay to a 4-finger ROI.
6. **Matching (next).** Extend matching to per-position 1:1 plus a fusion score
   across fingers (e.g. mean of top-k). The single-finger `match_templates`
   already gives the per-finger primitive.
7. **Harden** for production: bound thread concurrency on GPU, add request size
   limits, persist crops for audit, add WSQ/full ISO record headers if UIDAI
   certification requires it (current export is a compact FMR variant).

---

## 5. Running

```bash
# Use the same env as the uidai_app backend, or a fresh one:
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt        # tensorflow-macos/metal on Apple Silicon

python slap_app.py                     # http://0.0.0.0:5010
# in another shell:
python test_slap.py /path/to/slap.jpg right
```

Models load from `./models` (override with `SLAP_MODELS_DIR`). Enrolled
per-finger templates are written to `./slap.db` — **separate** from
`uidai_app`'s database.
```
```
