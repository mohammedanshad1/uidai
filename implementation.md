# UIDAI Biometric Capture Pipeline Implementation Guide

This document explains the implementation approach for a UIDAI-style biometric capture pipeline that is optimized for low latency, on-device preprocessing, and secure cloud matching.

## 1. Goal

The goal is to keep the full end-to-end capture experience under 5 seconds while:

- running as much processing as possible on the device,
- keeping only template generation and matching in the cloud,
- preserving security and UIDAI compliance.

## 2. What the current app does

The Flutter app in the uidai project now includes:

- a splash screen for app startup,
- a capture screen for biometric input,
- a device-side quality gate before cloud submission,
- a success screen after authentication completes.

This is the first production-ready slice of the full architecture.

## 3. Recommended architecture

### On-device stages
The following should run locally on Android and iOS:

- camera acquisition
- image normalization and frame conversion
- blur, brightness, and glare checks
- finger or slap region detection
- liveness validation
- segmentation and cropping
- compression of the ROI

### Cloud-only stages
These remain in the cloud:

- biometric template generation
- template matching
- identity verification and policy enforcement

## 4. Runtime choices

| Stage | Recommended runtime |
|---|---|
| Camera | Android CameraX / iOS AVFoundation |
| Quality checks | Native C++ + OpenCV via Dart FFI |
| Detection | TFLite with NNAPI / Core ML delegates |
| Liveness | TFLite |
| Segmentation | TFLite U2Net or OpenCV-based mask extraction |
| Compression | Native image processing / FFI |
| Cloud template generation | Secure backend service |
| Cloud matching | UIDAI-compliant backend |

## 5. Latency budget target

| Stage | Target |
|---|---:|
| Camera + conversion | 40 ms |
| Quality checks | 40 ms |
| Detection | 100 ms |
| Liveness | 120 ms |
| Segmentation | 150 ms |
| Compression | 60 ms |
| Upload | 500 ms |
| Cloud template generation | 450 ms |
| Cloud matching | 300 ms |
| Response | 200 ms |
| Total | 1,960 ms |

This is well under the 5 second target.

## 6. Fallback strategy

If on-device processing fails, the app should gracefully fall back to cloud processing.

Fallback rules:

- low quality capture -> guide the user to improve lighting or positioning
- model load failure -> use a lightweight fallback or cloud-only path
- network outage -> queue the encrypted payload and retry later
- unsupported device -> degrade to simpler checks and use cloud matching

## 7. Flutter integration plan

The Flutter app should use:

- Camera plugin for frame acquisition
- Pigeon or platform channels for native camera access
- Dart FFI for OpenCV and TFLite bridging
- background isolates for inference work
- encrypted temporary storage for offline queueing
- a simple state machine for capture progress

## 8. Current implementation status

The current Flutter app already contains:

- a polished splash screen,
- a post-authentication success screen,
- a capture pipeline service with quality gates,
- a testable device-side pipeline contract.

## 9. Next implementation steps

1. Replace placeholder image processing with native OpenCV checks.
2. Wire real TFLite inference for detection and liveness.
3. Add encrypted payload upload and offline retry support.
4. Connect the cloud template generation and matching endpoints.

## 10. Summary

This implementation path balances speed, security, and compliance. It keeps the most latency-sensitive processing on the device while protecting the highest-risk biometric steps in the cloud.
