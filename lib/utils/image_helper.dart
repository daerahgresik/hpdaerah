import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageHelper {
  /// Compress image file to be under maxKiloBytes
  static Future<File> compressImage({
    required File file,
    int maxKiloBytes = 200,
    int quality = 85,
  }) async {
    try {
      final originSize = await file.length();
      if (originSize <= maxKiloBytes * 1024) {
        debugPrint('Image already small enough: ${originSize / 1024} KB');
        return file;
      }

      debugPrint('Compressing image: ${originSize / 1024} KB');

      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
        dir.absolute.path,
        'temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Start with initial quality
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) return file;

      var compressedFile = File(result.path);
      var compressedSize = await compressedFile.length();

      // If still too large, loop with decreasing quality
      while (compressedSize > maxKiloBytes * 1024 && quality > 10) {
        quality -= 10;
        debugPrint(
          'Still too large: ${compressedSize / 1024} KB. Retrying with quality $quality',
        );

        // Delete previous temp file
        if (await compressedFile.exists()) {
          await compressedFile.delete();
        }

        final newTargetPath = p.join(
          dir.absolute.path,
          'temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          newTargetPath,
          quality: quality,
          format: CompressFormat.jpeg,
          minWidth: 800,
          minHeight: 800,
        );

        if (result == null) break;
        compressedFile = File(result.path);
        compressedSize = await compressedFile.length();
      }

      debugPrint('Final compressed size: ${compressedSize / 1024} KB');
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file;
    }
  }
}
