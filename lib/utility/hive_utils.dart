import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../database.dart';
import '../misc/file_logger.dart';

Future<void> openHiveBox() async {
  try {
    await Hive.openBox<ImageMetadata>('imageMetadata');
  } catch (e) {
    FileLogger.log("Error opening Hive box: $e");
    await forceWipeDatabase();
    await Hive.openBox<ImageMetadata>('imageMetadata');
  }
}

Future<bool> forceWipeDatabase() async {
  try {
    // Close the box if it's open
    if (Hive.isBoxOpen('imageMetadata')) {
      await Hive.box<ImageMetadata>('imageMetadata').close();
    }

    // Delete the box from disk
    await Hive.deleteBoxFromDisk('imageMetadata');
    FileLogger.log("Box deleted successfully.");

    await forceWipeThumbnails();

    return true;
  } catch (deleteError) {
    FileLogger.log("Error deleting Hive box: $deleteError");
    return false;
  }
}

Future<bool> forceWipeThumbnails() async {
  try {
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final String thumbnailsDirPath =
        path.join(appSupportDir.path, 'thumbnails');

    final Directory thumbnailsDir = Directory(thumbnailsDirPath);
    if (await thumbnailsDir.exists()) {
      await thumbnailsDir.delete(recursive: true);
      FileLogger.log('Thumbnails cleared: $thumbnailsDir');
      return true;
    } else {
      FileLogger.log('Thumbnails directory does not exist: $thumbnailsDir');
    }
  } catch (e) {
    FileLogger.log("Error deleting Thumbnails box: $e");
  }
  return false;
}