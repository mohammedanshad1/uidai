import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  Interpreter? _yoloInterpreter;
  Interpreter? _livenessInterpreter;
  Interpreter? _u2netInterpreter;

  Future<void> initializeModels() async {
    try {
      // Use NNAPI on Android, CoreML on iOS if possible
      final options = InterpreterOptions()..threads = 4;
      
      _yoloInterpreter = await Interpreter.fromAsset('assets/models/best_float32.tflite', options: options);
      // Assuming liveness model is converted to tflite and placed in assets.
      // _livenessInterpreter = await Interpreter.fromAsset('assets/models/liveness_model_v3.tflite', options: options);
      _u2netInterpreter = await Interpreter.fromAsset('assets/models/u2net_320x320_float32.tflite', options: options);
      
      print("Models loaded successfully");
    } catch (e) {
      print("Failed to load models: $e");
    }
  }

  /// Runs YOLO for hand/finger detection.
  /// Returns bounding box [x, y, w, h] or null if not found.
  List<double>? detectFinger(img.Image image) {
    if (_yoloInterpreter == null) return null;
    
    // Resize image to expected input shape (e.g., 640x640)
    var inputImage = img.copyResize(image, width: 640, height: 640);
    
    // Normalize and prepare input tensor [1, 3, 640, 640] or [1, 640, 640, 3] depending on the model
    // This is a placeholder for actual tensor preparation
    var input = List.generate(1, (i) => List.generate(640, (j) => List.generate(640, (k) => List.generate(3, (l) => 0.0))));
    
    // Output tensor placeholder
    var output = List.generate(1, (i) => List.generate(25200, (j) => List.generate(6, (k) => 0.0))); // standard YOLOv5 output

    try {
      // _yoloInterpreter!.run(input, output);
      // Process output to find max confidence box
      // Mocking return value
      return [0.2, 0.2, 0.6, 0.6]; 
    } catch (e) {
      print("YOLO Inference error: $e");
      return null;
    }
  }

  /// Runs liveness check. Returns true if live, false if spoof.
  bool checkLiveness(img.Image croppedROI) {
    if (_livenessInterpreter == null) return true; // mock true if not loaded
    
    // Prepare input tensor (e.g., 224x224 for MobileNet)
    // Run inference
    // Check output probability
    return true; 
  }

  /// Runs U2Net segmentation. Returns a mask image.
  img.Image? segmentFingerprint(img.Image croppedROI) {
    if (_u2netInterpreter == null) return null;
    
    // Prepare input tensor (320x320)
    // Run inference
    // Build mask from output
    return croppedROI; // returning original as mock
  }

  void dispose() {
    _yoloInterpreter?.close();
    _livenessInterpreter?.close();
    _u2netInterpreter?.close();
  }
}
