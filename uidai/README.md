# UIDAI Capture Pipeline App

This project is a Flutter-based biometric capture application designed for a UIDAI-style pipeline. The app focuses on a production-ready path for reducing latency by running quality checks, detection, liveness validation, and segmentation on the device before sending a compact, secure payload to the cloud for template generation and matching.

## What this app does

The app currently provides:

- an attractive splash screen at startup,
- a camera-based capture flow,
- an on-device quality gate for brightness, blur, and capture readiness,
- a success screen after authentication completes,
- a reusable pipeline service that can be expanded toward full on-device inference.

## Architecture summary

```text
Camera stream
  -> CameraX / AVFoundation
  -> OpenCV quality checks
  -> TFLite detection + liveness
  -> segmentation + ROI compression
  -> encrypted payload
  -> cloud template generation + matching
  -> authentication result
```

### On-device processing
The device handles:

- camera capture,
- quality checks,
- ROI or finger detection,
- liveness checks,
- segmentation and cropping,
- compression of the captured biometric ROI.

### Cloud processing
The cloud handles:

- biometric template generation,
- matching against enrolled records,
- secure policy and authorization checks.

### Runtime and integration notes

- CameraX and AVFoundation provide native camera access.
- OpenCV is used for blur, brightness, and quality checks.
- Platform Channels and Pigeon are planned for native bridge communication.
- Dart FFI connects Flutter to native OpenCV and TFLite code.
- Isolates are used to keep frame processing off the UI thread.

## Fallback and resilience flow

If the on-device path is unavailable or weak, the app will:

1. retry the detection step a small number of times,
2. fall back to a cloud-only processing path when needed,
3. queue encrypted requests for offline retry when connectivity is poor.

## Folder structure

- lib/screens: UI screens such as the splash screen, capture screen, and success screen
- lib/services: pipeline logic, quality evaluation, and cloud submission flow
- lib/pipeline: capture orchestration logic
- lib/native: image processing helpers
- test: regression tests for the pipeline service

## Current implementation status

The current version is a working foundation for the production architecture:

- splash and success screens are implemented,
- the pipeline service evaluates image quality before upload,
- tests cover the capture quality gate and latency budget expectations.

## How to run

From the project root:

```bash
flutter pub get
flutter test test/app_smoke_test.dart test/capture_pipeline_service_test.dart
flutter run
```

## Important notes

This app is intentionally structured to evolve into a fully optimized pipeline:

- the current logic uses Dart-based quality checks,
- the next step is to replace these with native OpenCV and TFLite inference,
- the cloud handoff is prepared as a secure contract for template generation and matching.

## Documentation

For the detailed architecture plan, see [implementation.md](../implementation.md).
