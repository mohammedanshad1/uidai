import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../native/image_processor.dart';
import '../services/tflite_service.dart';

enum PipelineState {
  initializing,
  scanning,
  processing,
  completed,
  failed,
  fallback,
}

class PipelineController {
  final TFLiteService _tfliteService = TFLiteService();
  bool _isProcessingFrame = false;
  bool _offlineQueueEnabled = true;
  int _retryCount = 0;
  
  Function(String)? onGuidanceUpdate;
  Function(PipelineState)? onStateUpdate;
  Function(img.Image)? onCaptureSuccess;

  PipelineState _currentState = PipelineState.initializing;

  Future<void> initialize() async {
    await _tfliteService.initializeModels();
    _setState(PipelineState.scanning);
    _updateGuidance("Place finger in the frame");
  }

  void _setState(PipelineState state) {
    _currentState = state;
    onStateUpdate?.call(state);
  }

  void _updateGuidance(String message) {
    onGuidanceUpdate?.call(message);
  }

  void processCameraFrame(CameraImage cameraImage) async {
    if (_isProcessingFrame || _currentState != PipelineState.scanning) return;
    _isProcessingFrame = true;

    try {
      final image = ImageProcessor.convertCameraImage(cameraImage);
      final blur = ImageProcessor.calculateBlur(image);
      final brightness = ImageProcessor.calculateBrightness(image);

      if (brightness < 50) {
        _updateGuidance("Too dark. Move to better lighting.");
        _isProcessingFrame = false;
        return;
      }

      if (brightness > 220) {
        _updateGuidance("Too bright. Avoid glare.");
        _isProcessingFrame = false;
        return;
      }

      if (blur < 10) {
        _updateGuidance("Hold steady. Image is blurry.");
        _isProcessingFrame = false;
        return;
      }

      final bbox = await Isolate.run(() => _tfliteService.detectFinger(image));
      if (bbox == null) {
        _retryCount += 1;
        if (_retryCount < 3) {
          _updateGuidance("Finger not detected. Trying again...");
          _isProcessingFrame = false;
          return;
        }
        _setState(PipelineState.fallback);
        _updateGuidance("Falling back to cloud processing.");
        _isProcessingFrame = false;
        return;
      }

      final isLive = await Isolate.run(() => _tfliteService.checkLiveness(image));
      if (!isLive) {
        _updateGuidance("Spoof detected. Try again.");
        _isProcessingFrame = false;
        return;
      }

      _setState(PipelineState.processing);
      _updateGuidance("Processing capture...");

      final segmentedImage = await Isolate.run(() => _tfliteService.segmentFingerprint(image));
      if (segmentedImage != null) {
        _retryCount = 0;
        _setState(PipelineState.completed);
        onCaptureSuccess?.call(segmentedImage);
      } else {
        _setState(PipelineState.failed);
        _updateGuidance("Segmentation failed. Retrying later.");
      }
    } catch (e) {
      _setState(PipelineState.fallback);
      _updateGuidance("Device path failed. Using cloud fallback.");
    } finally {
      if (_currentState == PipelineState.scanning || _currentState == PipelineState.fallback) {
        _isProcessingFrame = false;
      }
    }
  }

  void dispose() {
    _tfliteService.dispose();
  }
}
