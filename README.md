# UIDAI Capture Pipeline App

## Overview

This project is a Flutter-based Proof of Concept (PoC) developed for the **YellowSense Technologies UIDAI Flutter Developer Challenge**.

The objective is to demonstrate an **offline-first biometric capture pipeline** where all latency-sensitive processing is performed on the mobile device, while **biometric template generation** and **matching** remain cloud-based, as required by the challenge.

The project emphasizes modular architecture, scalability, low latency, and a production-ready integration approach rather than production-grade biometric accuracy.

---

# Features

The application includes:

- Modern splash screen
- Camera-based biometric capture
- On-device image quality assessment
- Finger ROI detection pipeline (PoC)
- Basic liveness validation pipeline (PoC)
- Finger segmentation pipeline (PoC)
- Background inference using Dart Isolates
- Retry and fallback handling
- Secure cloud handoff
- Authentication success screen
- Modular service-based architecture
- Unit tests for the capture pipeline

---

# Architecture

## On-Device Processing

The following operations are designed to execute entirely on the mobile device:

- Camera Preview
- Image Capture
- Brightness Analysis
- Blur Detection
- Image Quality Assessment
- Finger ROI Detection
- Basic Liveness Validation
- Finger Segmentation
- Image Compression
- Secure Upload Preparation

Heavy processing tasks are executed using **Dart Isolates** to keep the Flutter UI responsive.

---

## Cloud Processing

Only the following operations are delegated to the cloud:

- Biometric Template Generation
- Template Matching
- Authentication Scoring
- Security Validation

This minimizes network dependency while keeping sensitive template generation centralized.

---

# Capture Pipeline

```
Flutter UI
     │
     ▼
Camera Preview
     │
     ▼
Image Capture
     │
     ▼
Quality Assessment
     │
     ▼
Finger Detection
     │
     ▼
Liveness Validation
     │
     ▼
Segmentation
     │
     ▼
Image Compression
     │
     ▼
Cloud API
     │
     ├── Template Generation
     ├── Matching
     └── Authentication Result
```

---

# Runtime / Conversion Plan

| Component | Current Implementation | Production Path |
|------------|------------------------|-----------------|
| Camera | Flutter Camera Plugin | CameraX / AVFoundation |
| Image Quality | Dart | OpenCV |
| Finger Detection | TensorFlow Lite (PoC) | Optimized TFLite Model |
| Liveness Detection | TensorFlow Lite (PoC) | Optimized TFLite Model |
| Finger Segmentation | TensorFlow Lite (PoC) | Optimized TFLite Model |
| Background Processing | Dart Isolates | Native Threads / Isolates |
| Native Integration | Architecture Ready | Platform Channels / Flutter FFI |
| Template Generation | Cloud | Cloud |
| Matching | Cloud | Cloud |

---

# Proposed Latency Budget

| Stage | Target Time |
|--------|-------------|
| Camera Initialization | 300 ms |
| Finger Detection | 500 ms |
| Image Quality Assessment | 300 ms |
| Liveness Detection | 500 ms |
| Image Capture | 500 ms |
| Segmentation | 700 ms |
| Compression | 300 ms |

**Target On-Device Processing:** **3–4 seconds**

Cloud Processing Target

| Stage | Target Time |
|--------|-------------|
| Upload | 500 ms |
| Template Generation | 700 ms |
| Matching | 800 ms |

**Overall Target:** **Under 5 seconds**, as proposed in the challenge architecture.

---

# Fallback Strategy

If on-device processing cannot complete successfully, the application follows a structured recovery flow.

### Finger Not Detected

- Prompt user to reposition finger
- Retry capture

### Poor Image Quality

- Display guidance
- Retry up to three attempts

### Low Lighting

- Request improved lighting
- Retry capture

### Liveness Failure

- Reject capture
- Restart pipeline

### On-Device Processing Failure

- Switch to fallback processing flow
- Upload securely for cloud-side preprocessing (if permitted)

### Network Unavailable

- Cache capture locally
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

# Technology Stack

## Current Implementation

- Flutter
- Dart
- Flutter Camera Plugin
- TensorFlow Lite (`tflite_flutter`)
- Dart Isolates

## Production Architecture

- CameraX (Android)
- AVFoundation (iOS)
- OpenCV
- Platform Channels
- Flutter FFI
- GPU / NNAPI acceleration

---

# Current Implementation Status

This project demonstrates the proposed architecture by implementing:

- Camera capture flow
- Image quality assessment
- Modular pipeline controller
- TFLite interpreter integration (PoC)
- Finger detection pipeline (PoC)
- Liveness validation pipeline (PoC)
- Finger segmentation pipeline (PoC)
- Background processing using Dart Isolates
- Retry and fallback handling
- Secure cloud request preparation
- Unit testing for pipeline components

The included machine learning integration demonstrates the intended inference workflow. The bundled models and inference outputs are provided as Proof of Concept integrations and are intended to illustrate the application architecture rather than production-ready biometric accuracy.

---

# Production Roadmap

Future improvements include:

- Native OpenCV preprocessing
- CameraX integration
- GPU / NNAPI delegates
- Optimized TensorFlow Lite models
- Native SIMD image processing
- Continuous frame-based auto capture
- Advanced liveness detection
- Secure hardware-backed biometric storage

---

# Running the Project

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

A detailed explanation of the proposed architecture, runtime strategy, latency budget, fallback mechanism, and Flutter integration approach is available in:

**implementation.md**

---

# Conclusion

This project demonstrates a modular, offline-first biometric capture pipeline designed for the UIDAI Flutter Developer Challenge.

The proposed architecture moves latency-sensitive operations—including capture, quality assessment, detection, liveness validation, and segmentation—to the mobile device while retaining template generation and biometric matching in the cloud. The implementation provides a scalable Flutter foundation that can be extended with native image processing and production-grade machine learning models without significant architectural changes.
