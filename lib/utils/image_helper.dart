import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageHelper {
  /// Compress image file to be under maxKiloBytes
  static Future<File> compressImage({
    required File file,
    int maxKiloBytes = 200, // Default to 200KB (for profile), can be overridden
    int quality = 80,
  }) async {
    try {
      final originSize = await file.length();
      if (originSize <= maxKiloBytes * 1024) {
        debugPrint('Image already small enough: ${originSize / 1024} KB');
        return file;
      }

      debugPrint('Compressing image: ${originSize / 1024} KB');

      final dir = await path_provider.getTemporaryDirectory();
      var currentWidth = 1024;
      var currentHeight = 1024;

      File? compressedFile;
      var compressedSize = originSize;

      // Smart Iterative Compression
      while (compressedSize > maxKiloBytes * 1024 && quality > 5) {
        final targetPath = p.join(
          dir.absolute.path,
          'comp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          format: CompressFormat.jpeg,
          minWidth: currentWidth,
          minHeight: currentHeight,
        );

        if (result == null) break;

        // Clean up previous temp file
        if (compressedFile != null && await compressedFile.exists()) {
          await compressedFile.delete();
        }

        compressedFile = File(result.path);
        compressedSize = await compressedFile.length();

        debugPrint(
          'Current Iteration: Q:$quality, W:$currentWidth, Size: ${compressedSize / 1024} KB',
        );

        // If still too large, get "smarter": reduce quality AND dimensions
        if (compressedSize > maxKiloBytes * 1024) {
          quality -= 15;
          if (currentWidth > 600) {
            currentWidth = (currentWidth * 0.8).toInt();
            currentHeight = (currentHeight * 0.8).toInt();
          }
        }
      }

      return compressedFile ?? file;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file;
    }
  }
}
