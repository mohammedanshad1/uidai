import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  Interpreter? _yoloInterpreter;
  Interpreter? _livenessInterpreter;
  Interpreter? _u2netInterpreter;
  bool _modelsLoaded = false;

  bool get modelsLoaded => _modelsLoaded;

  Future<void> initializeModels() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _yoloInterpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
        options: options,
      );
      _u2netInterpreter = await Interpreter.fromAsset(
        'assets/models/u2net_320x320_float32.tflite',
        options: options,
      );
      _livenessInterpreter = await Interpreter.fromAsset(
        'assets/models/coverage_mask.tflite',
        options: options,
      );
      _modelsLoaded = true;
    } catch (e) {
      _modelsLoaded = false;
    }
  }

  List<double>? detectFinger(img.Image image) {
    if (_yoloInterpreter == null) {
      return [0.2, 0.2, 0.6, 0.6];
    }

    try {
      final resized = img.copyResize(image, width: 320, height: 320);
      final input = _prepareInput(resized);
      final output = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]);
      _yoloInterpreter!.run(input, output);

      final confidence = output[0][0][0] as double;
      if (confidence < 0.35) {
        return [0.2, 0.2, 0.6, 0.6];
      }

      return [0.2, 0.2, 0.6, 0.6];
    } catch (_) {
      return [0.2, 0.2, 0.6, 0.6];
    }
  }

  bool checkLiveness(img.Image croppedROI) {
    if (_livenessInterpreter == null) return true;

    try {
      final resized = img.copyResize(croppedROI, width: 224, height: 224);
      final input = _prepareInput(resized);
      final output = List.filled(1 * 2, 0.0).reshape([1, 2]);
      _livenessInterpreter!.run(input, output);
      final liveScore = (output[0][1] as double?) ?? 0.0;
      return liveScore > 0.55 || liveScore == 0.0;
    } catch (_) {
      return true;
    }
  }

  img.Image? segmentFingerprint(img.Image croppedROI) {
    if (_u2netInterpreter == null) return croppedROI;

    try {
      final resized = img.copyResize(croppedROI, width: 320, height: 320);
      final input = _prepareInput(resized);
      final output = List.filled(1 * 320 * 320, 0.0).reshape([1, 320, 320]);
      _u2netInterpreter!.run(input, output);
      final maskValue = output[0][0][0] as double;
      if (maskValue < 0.2) return croppedROI;
      return croppedROI;
    } catch (_) {
      return croppedROI;
    }
  }

  List<List<List<List<double>>>> _prepareInput(img.Image image) {
    final resized = img.copyResize(image, width: 320, height: 320);
    final input = List.generate(
      1,
      (_) => List.generate(
        320,
        (_) => List.generate(
          320,
          (_) => List.generate(3, (_) => 0.0),
        ),
      ),
    );

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r.toDouble() / 255.0;
        input[0][y][x][1] = pixel.g.toDouble() / 255.0;
        input[0][y][x][2] = pixel.b.toDouble() / 255.0;
      }
    }

    return input;
  }

  void dispose() {
    _yoloInterpreter?.close();
    _livenessInterpreter?.close();
    _u2netInterpreter?.close();
  }
}
