# UIDAI Capture Pipeline App

## Overview

This project is a Flutter-based Proof of Concept (PoC) developed for the **YellowSense Technologies UIDAI Flutter Developer Challenge**.

The objective is to demonstrate an **offline-first biometric capture pipeline** where latency-sensitive operations are performed on the mobile device, while **biometric template generation** and **matching** remain cloud-based, as required by the assignment.

The project focuses on architecture, modularity, low latency, and production-ready integration rather than production-grade biometric model accuracy.

---

# Features

The application currently includes:

- Modern splash screen
- Camera-based biometric capture
- On-device image quality assessment
- Finger detection pipeline (PoC)
- Basic liveness validation pipeline (PoC)
- Finger segmentation pipeline (PoC)
- Background inference using Dart Isolates
- Retry and fallback handling
- Secure cloud request preparation
- Authentication success screen
- Modular service-based architecture
- Unit tests for pipeline components

---

# Architecture Summary

```text
Flutter UI
     │
     ▼
Flutter Camera
     │
     ▼
Image Capture
     │
     ▼
On-Device Processing
 ├── Quality Assessment
 ├── Finger Detection (TFLite)
 ├── Liveness Validation (TFLite)
 ├── Finger Segmentation (TFLite)
 ├── Image Compression
 └── Secure Payload Preparation
     │
     ▼
Cloud API
 ├── Template Generation
 ├── Biometric Matching
 └── Authentication Result
```

---

# On-Device Processing

The following stages are executed on the device:

- Camera preview and capture
- Image quality assessment
- Finger ROI detection
- Basic liveness validation
- Finger segmentation
- Image compression
- Secure payload preparation

Heavy processing tasks are executed using **Dart Isolates** to keep the Flutter UI responsive.

---

# Cloud Processing

The cloud is responsible for:

- Biometric template generation
- Biometric matching
- Authentication scoring
- Security validation

Only processed biometric data is transmitted to the server, minimizing bandwidth and improving privacy.

---

# Runtime & Integration Plan

| Component | Current Implementation | Production Architecture |
|------------|------------------------|-------------------------|
| Camera | Flutter Camera Plugin | CameraX (Android) / AVFoundation (iOS) |
| Image Quality Assessment | Dart | Native OpenCV |
| Finger Detection | TensorFlow Lite (PoC) | Optimized TensorFlow Lite |
| Liveness Validation | TensorFlow Lite (PoC) | Optimized TensorFlow Lite |
| Finger Segmentation | TensorFlow Lite (PoC) | Optimized TensorFlow Lite |
| Background Processing | Dart Isolates | Native Threads / Isolates |
| Native Integration | Architecture Ready | Platform Channels / Flutter FFI |
| Template Generation | Cloud | Cloud |
| Matching | Cloud | Cloud |

---

# Proposed Latency Budget

| Stage | Target Time |
|--------|-------------|
| Camera Initialization | 300 ms |
| Image Quality Assessment | 300 ms |
| Finger Detection | 500 ms |
| Liveness Validation | 500 ms |
| Image Capture | 500 ms |
| Finger Segmentation | 700 ms |
| Image Compression | 300 ms |

**Target On-Device Processing:** **3–4 seconds**

| Cloud Stage | Target Time |
|-------------|-------------|
| Upload | 500 ms |
| Template Generation | 700 ms |
| Matching | 800 ms |

**Overall Target:** **Under 5 Seconds**

---

# Fallback Strategy

If on-device processing cannot complete successfully, the application follows a structured recovery flow.

### Finger Not Detected

- Prompt the user to reposition the finger
- Retry detection

### Poor Image Quality

- Display guidance
- Retry capture (up to three attempts)

### Low Lighting

- Ask the user to improve lighting
- Retry capture

### Liveness Failure

- Reject the capture
- Restart the capture pipeline

### On-Device Processing Failure

- Switch to fallback processing
- Upload securely for cloud-side processing (if permitted)

### Network Unavailable

- Cache the encrypted request locally
- Retry upload when connectivity is restored

---

# Folder Structure

```
lib/
├── pipeline/
├── screens/
├── services/
├── native/
├── widgets/
└── main.dart

assets/
└── models/

test/
```

---

# Current Implementation Status

This Proof of Concept currently demonstrates:

- Camera capture flow
- Image quality assessment
- Modular capture pipeline
- TensorFlow Lite interpreter integration (PoC)
- Finger detection workflow (PoC)
- Liveness validation workflow (PoC)
- Finger segmentation workflow (PoC)
- Background processing using Dart Isolates
- Retry and fallback handling
- Secure cloud request preparation
- Unit tests for the capture pipeline

The bundled machine learning models demonstrate the intended inference workflow and integration. They represent the proposed application architecture and are **not intended to represent production-trained biometric models**.

---

# Production Roadmap

Future enhancements include:

- Native OpenCV preprocessing
- CameraX integration
- GPU / NNAPI acceleration
- Optimized TensorFlow Lite models
- Native SIMD image processing
- Continuous frame-based auto capture
- Advanced liveness detection
- Hardware-backed biometric security

---

# How to Run

Install dependencies:

```bash
flutter pub get
```

Run tests:

```bash
flutter test test/app_smoke_test.dart test/capture_pipeline_service_test.dart
```

Run the application:

```bash
flutter run
```

---

# Documentation

Detailed architecture documentation is available in:

**implementation.md**

This document explains:

- On-device pipeline
- Runtime and conversion strategy
- Latency budget
- Fallback mechanism
- Flutter integration approach

---

# Important Notes

- This project is a Proof of Concept created for the YellowSense Technologies Flutter Developer Challenge.
- The architecture follows the challenge requirement of moving latency-sensitive processing onto the device while keeping template generation and biometric matching in the cloud.
- TensorFlow Lite is integrated as the on-device inference runtime.
- Image quality assessment is currently implemented in Dart and can be migrated to native OpenCV for improved performance.
- The architecture is designed to support Platform Channels, Flutter FFI, CameraX, and native image processing without changing the Flutter presentation layer.

---

# Conclusion

This project demonstrates a modular, scalable, and offline-first biometric capture pipeline suitable for the UIDAI Flutter Developer Challenge.

The proposed architecture performs quality assessment, detection, liveness validation, segmentation, and secure payload preparation on the mobile device while delegating biometric template generation and matching to the cloud. The implementation provides a clean Flutter foundation that can be extended with native image processing and production-grade machine learning models for real-world deployment.