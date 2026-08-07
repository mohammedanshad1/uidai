import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uidai/services/capture_pipeline_service.dart';

void main() {
  group('CapturePipelineService', () {
    test('rejects low brightness captures before upload', () {
      final service = CapturePipelineService();
      final image = img.Image(width: 64, height: 64);

      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(x, y, 10, 10, 10, 255);
        }
      }

      final quality = service.evaluateQuality(image);
      expect(quality.shouldContinue, isFalse);
      expect(quality.reason, contains('too dark'));
    });

    test('keeps the staged latency budget under the 5 second target', () {
      final budget = CapturePipelineService.latencyBudget();
      final total = budget.values.fold<int>(0, (sum, entry) => sum + entry);

      expect(total, lessThanOrEqualTo(5000));
    });
  });
}
