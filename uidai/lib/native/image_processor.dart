import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  /// Converts a CameraImage (YUV420) to an Image package object.
  static img.Image convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(image);
      }
    } catch (e) {
      print("ERROR: $e");
    }
    return img.Image(width: 0, height: 0);
  }

  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img.Image imgObject = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      int pY = y * image.planes[0].bytesPerRow;
      int pUV = (y >> 1) * uvRowStride;

      for (int x = 0; x < width; x++) {
        int uvOffset = pUV + (x >> 1) * uvPixelStride;

        final yp = image.planes[0].bytes[pY];
        final up = image.planes[1].bytes[uvOffset];
        final vp = image.planes[2].bytes[uvOffset];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        imgObject.setPixelRgba(x, y, r, g, b, 255);
        pY++;
      }
    }
    return imgObject;
  }

  /// Calculates Laplacian Variance for blur detection
  static double calculateBlur(img.Image image) {
    // In a production app, this would be an FFI call to OpenCV's Laplacian
    // For this implementation, we approximate it or use a simplified variance.
    img.Image grayscale = img.grayscale(image);
    double mean = 0;
    int count = grayscale.width * grayscale.height;
    
    for (var p in grayscale) {
      mean += p.r;
    }
    mean /= count;

    double variance = 0;
    for (var p in grayscale) {
      variance += (p.r - mean) * (p.r - mean);
    }
    variance /= count;
    
    return variance;
  }

  /// Calculates mean brightness
  static double calculateBrightness(img.Image image) {
    img.Image grayscale = img.grayscale(image);
    double mean = 0;
    int count = grayscale.width * grayscale.height;
    
    for (var p in grayscale) {
      mean += p.r;
    }
    return mean / count;
  }
}
