# UIDAI IITB Contactless Preprocessing (Slap)

This branch contains the slap (multi-finger) preprocessing backend and the slap Flutter app inside:
- `UIDAI-IITB-CONTACTLESS-preprocessing/`

## Backend (Slap) Run

```bash
cd UIDAI-IITB-CONTACTLESS-preprocessing
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
PORT=5010 python slap_app.py
```

Health check:
- http://127.0.0.1:5010/health

## Flutter App Run

```bash
cd UIDAI-IITB-CONTACTLESS-preprocessing/slap_flutter_app
flutter pub get
flutter run
```

## Models (Large Files)
This repo does not commit model binaries. Place the model files under:
- `UIDAI-IITB-CONTACTLESS-preprocessing/models/`

Required files:
- `best_float32.tflite` (slap finger detector)
- `u2net_320x320_float32.tflite`
- `zero_dce_model.h5`
- `best_f1.pth`
- `liveness_model_v3.pt`
- `best-new.pt` (if used by your configuration)

## Repo Branches (High Level)
- `feature/slap-preprocessing` (this branch): slap preprocessing snapshot
- `feature/uidai-unified`: unified app (single + slap)
- `feature/uidai-app`: original single-finger app

## New Developer Onboarding (Suggested Checklist)
- Run the slap backend and verify `/health`.
- Run `slap_flutter_app` and point it to the slap backend URL (Settings).
- Read key files:
  - `UIDAI-IITB-CONTACTLESS-preprocessing/slap_app.py` (endpoints + orchestration)
  - `UIDAI-IITB-CONTACTLESS-preprocessing/slap_core.py` (model inference + preprocessing)
  - `UIDAI-IITB-CONTACTLESS-preprocessing/slap_flutter_app/lib/widgets/fingerprint_camera_widget.dart` (auto-capture + overlays)
