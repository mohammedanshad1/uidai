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
}

class PipelineController {
  final TFLiteService _tfliteService = TFLiteService();
  bool _isProcessingFrame = false;
  
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
      // 1. Convert YUV to Image (Ideally via FFI in C++ for speed, done in Dart here)
      img.Image image = ImageProcessor.convertCameraImage(cameraImage);

      // 2. Quality Checks (Blur & Brightness)
      double blur = ImageProcessor.calculateBlur(image);
      double brightness = ImageProcessor.calculateBrightness(image);

      if (brightness < 50) {
        _updateGuidance("Too dark. Move to better lighting.");
        _isProcessingFrame = false;
        return;
      } else if (brightness > 200) {
        _updateGuidance("Too bright. Avoid glare.");
        _isProcessingFrame = false;
        return;
      }

      if (blur < 10) { // arbitrary threshold
        _updateGuidance("Hold steady. Image is blurry.");
        _isProcessingFrame = false;
        return;
      }

      // 3. Object Detection (YOLO)
      List<double>? bbox = _tfliteService.detectFinger(image);
      if (bbox == null) {
        _updateGuidance("Finger not detected.");
        _isProcessingFrame = false;
        return;
      }

      // 4. Liveness Check
      bool isLive = _tfliteService.checkLiveness(image);
      if (!isLive) {
        _updateGuidance("Spoof detected. Try again.");
        _isProcessingFrame = false;
        return;
      }

      // If all checks pass, we trigger the capture
      _setState(PipelineState.processing);
      _updateGuidance("Processing capture...");

      // 5. Segmentation & Crop
      img.Image? segmentedImage = _tfliteService.segmentFingerprint(image);
      
      // 6. Return the success result
      if (segmentedImage != null) {
        _setState(PipelineState.completed);
        onCaptureSuccess?.call(segmentedImage);
      } else {
        _setState(PipelineState.failed);
        _updateGuidance("Segmentation failed.");
      }
      
    } catch (e) {
      print("Frame processing error: $e");
      _updateGuidance("Error processing frame");
    } finally {
      if (_currentState == PipelineState.scanning) {
        _isProcessingFrame = false;
      }
    }
  }

  void dispose() {
    _tfliteService.dispose();
  }
}
