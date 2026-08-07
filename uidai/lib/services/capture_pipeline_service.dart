import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CaptureQualityResult {
  final bool shouldContinue;
  final String reason;
  final double blur;
  final double brightness;

  const CaptureQualityResult({
    required this.shouldContinue,
    required this.reason,
    required this.blur,
    required this.brightness,
  });
}

class CapturePipelineService {
  static Map<String, int> latencyBudget() {
    return {
      'capture_and_conversion': 70,
      'quality_checks': 40,
      'finger_detection': 100,
      'liveness': 120,
      'segmentation': 180,
      'compression': 80,
      'upload': 600,
      'cloud_template_generation': 500,
      'cloud_matching': 300,
      'response': 200,
    };
  }

  CaptureQualityResult evaluateQuality(img.Image image) {
    final grayscale = img.grayscale(image);
    double mean = 0;
    final totalPixels = grayscale.width * grayscale.height;

    for (final pixel in grayscale) {
      mean += pixel.r.toDouble();
    }
    mean /= totalPixels;

    double variance = 0;
    for (final pixel in grayscale) {
      variance += (pixel.r.toDouble() - mean) * (pixel.r.toDouble() - mean);
    }
    variance /= totalPixels;

    if (mean < 45) {
      return const CaptureQualityResult(
        shouldContinue: false,
        reason: 'Image is too dark for reliable capture.',
        blur: 0,
        brightness: 0,
      );
    }

    if (mean > 220) {
      return const CaptureQualityResult(
        shouldContinue: false,
        reason: 'Image is too bright and may contain glare.',
        blur: 0,
        brightness: 0,
      );
    }

    if (variance < 30) {
      return const CaptureQualityResult(
        shouldContinue: false,
        reason: 'Image is too blurry to proceed.',
        blur: 0,
        brightness: 0,
      );
    }

    return CaptureQualityResult(
      shouldContinue: true,
      reason: 'Quality checks passed.',
      blur: variance,
      brightness: mean,
    );
  }

  Future<Uint8List> compressForCloud(img.Image image) async {
    final pngBytes = img.encodePng(image);
    return Future.value(Uint8List.fromList(pngBytes));
  }

  Future<Map<String, dynamic>> submitToCloud(Uint8List payload) async {
    return {
      'status': 'accepted',
      'templateId': 'template_${DateTime.now().millisecondsSinceEpoch}',
      'latencyMs': 650,
    };
  }
}
