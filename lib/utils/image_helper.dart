import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  ImageHelper._();

  static Future<File> compressImage(File file, {int maxDimension = 1080, int quality = 80}) async {
    return await compute(_compressTask, {
      'file': file,
      'maxDimension': maxDimension,
      'quality': quality,
    });
  }

  static Future<File> _compressTask(Map<String, dynamic> args) async {
    final File file = args['file'];
    final int maxDimension = args['maxDimension'];
    final int quality = args['quality'];

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return file;

      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return file;

      img.Image resizedImage = decodedImage;
      if (decodedImage.width > maxDimension || decodedImage.height > maxDimension) {
        if (decodedImage.width > decodedImage.height) {
          resizedImage = img.copyResize(decodedImage, width: maxDimension);
        } else {
          resizedImage = img.copyResize(decodedImage, height: maxDimension);
        }
      }

      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      print('Image compression failed: $e');
      return file;
    }
  }
}
