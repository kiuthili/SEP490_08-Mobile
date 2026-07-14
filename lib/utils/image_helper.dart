import 'dart:io';
import 'package:image/image.dart' as img;

class ImageHelper {
  ImageHelper._();

  /// Nén và giảm kích thước ảnh về chiều rộng/cao tối đa (ví dụ 1080px)
  /// giúp giảm dung lượng tệp từ 10MB xuống ~150KB-300KB,
  /// giúp tải lên qua mạng tunnel (ngrok, devtunnel) nhanh gấp 50 lần.
  static Future<File> compressImage(File file, {int maxDimension = 1080, int quality = 80}) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return file;

      // Giải mã ảnh sử dụng thư viện pure-Dart image
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return file;

      // Chỉ thay đổi kích thước nếu ảnh vượt quá giới hạn chiều rộng/cao
      img.Image resizedImage = decodedImage;
      if (decodedImage.width > maxDimension || decodedImage.height > maxDimension) {
        if (decodedImage.width > decodedImage.height) {
          resizedImage = img.copyResize(decodedImage, width: maxDimension);
        } else {
          resizedImage = img.copyResize(decodedImage, height: maxDimension);
        }
      }

      // Mã hóa lại thành JPG với chất lượng chỉ định
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);

      // Ghi đè vào tệp tạm mới hoặc tệp cũ
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      final originalSize = bytes.length;
      final newSize = compressedBytes.length;
      print('=== IMAGE COMPRESSION SUCCESS ===');
      print('Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      print('Compressed size: ${(newSize / 1024).toStringAsFixed(2)} KB');
      print('Dimensions: ${resizedImage.width}x${resizedImage.height}');
      print('=================================');

      return tempFile;
    } catch (e) {
      print('Image compression failed, uploading original: $e');
      return file;
    }
  }
}
