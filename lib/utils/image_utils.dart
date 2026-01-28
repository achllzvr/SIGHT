import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

// Standard YUV to RGB (Keep this as is)
img.Image convertYUV420ToImage(CameraImage cameraImage) {
  final int width = cameraImage.width;
  final int height = cameraImage.height;
  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  var image = img.Image(width: width, height: height);

  for (int w = 0; w < width; w++) {
    for (int h = 0; h < height; h++) {
      final int uvIndex = uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
      final int index = h * width + w;
      final y = cameraImage.planes[0].bytes[index];
      final u = cameraImage.planes[1].bytes[uvIndex];
      final v = cameraImage.planes[2].bytes[uvIndex];

      int r = (y + v * 1.402 - 0.701 * 255).toInt().clamp(0, 255);
      int g = (y - u * 0.34414 - v * 0.71414 + 0.529 * 255).toInt().clamp(0, 255);
      int b = (y + u * 1.772 - 0.886 * 255).toInt().clamp(0, 255);

      image.setPixelRgb(w, h, r, g, b);
    }
  }
  return image;
}

// CONVERTER: Float32 Normalized [0.0 - 1.0]
Float32List imageToByteListFloat32(img.Image image, int inputSize) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;

  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = pixel.r.toDouble() / 255.0;
      buffer[pixelIndex++] = pixel.g.toDouble() / 255.0;
      buffer[pixelIndex++] = pixel.b.toDouble() / 255.0;
    }
  }
  return convertedBytes;
}