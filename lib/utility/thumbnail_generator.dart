import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../misc/file_logger.dart';

class ThumbnailConfig {
  final int quality;
  final int minWidth;
  final int minHeight;

  ThumbnailConfig({
    this.quality = 80,
    this.minWidth = 500,
    this.minHeight = 500,
  });
}

Future<String?> generateThumbnail(File imageFile, ThumbnailConfig config) async {
  try {
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final String thumbnailsDirPath = path.join(appSupportDir.path, 'thumbnails');
    final String fileName = path.basename(imageFile.path);
    final String thumbnailPath = path.join(thumbnailsDirPath,
        '${path.basenameWithoutExtension(fileName)}_thumb.jpg');

    final File thumbnailFile = File(thumbnailPath);
    if (await thumbnailFile.exists()) {
      return thumbnailPath;
    }

    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image originalImage = img.decodeImage(imageBytes)!;

    int width = originalImage.width;
    int height = originalImage.height;

    if (width > config.minWidth || height > config.minHeight) {
      double aspectRatio = width / height;
      if (config.minWidth / aspectRatio <= config.minHeight) {
        width = config.minWidth;
        height = (config.minWidth / aspectRatio).round();
      } else {
        height = config.minHeight;
        width = (config.minHeight * aspectRatio).round();
      }
    }

    final img.Image resizedImage = img.copyResize(originalImage, width: width, height: height);
    final Uint8List jpegBytes = img.encodeJpg(resizedImage, quality: config.quality);

    await Directory(thumbnailsDirPath).create(recursive: true);
    await thumbnailFile.writeAsBytes(jpegBytes);

    return thumbnailPath;
  } catch (e, stackTrace) {
    FileLogger.log('Error generating thumbnail: $e');
    await FileLogger.log("Stack trace: $stackTrace");
    return null;
  }
}
Future<List<String?>> getThumbnailPathList(List<File> listImages) async {
  ThumbnailConfig config = ThumbnailConfig();
  return await Future.wait(listImages.map((image) => generateThumbnail(
        image,
        config,
      )));
}

