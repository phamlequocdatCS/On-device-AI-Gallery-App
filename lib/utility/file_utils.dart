import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../constants.dart';
import '../misc/file_logger.dart';

Future<File> getFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return file;
  } else {
    throw Exception('File not found at path: $path');
  }
}

Future<String> getFileSizeMB(File imageFile) async {
  int fileSizeInBytes = await imageFile.length();
  return '${(fileSizeInBytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

bool isImageFile(String filePath) {
  return validExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
}

List<File> getValidFiles(String selectedDirectory) {
  List<FileSystemEntity> files = Directory(selectedDirectory).listSync();

  List<File> validFiles = [];
  validFiles.addAll(files.whereType<File>());
  return validFiles;
}

Future<String> getFilePath(File imageFile, String filename) async {
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;

    if (androidInfo.version.sdkInt >= 33) {
      // For Android 13 and above
      return await getPathAndroid13(imageFile, filename);
    } else {
      // For Android 12 and below
      return await getPathAndroid12(imageFile, filename);
    }
  } else if (Platform.isWindows) {
    return imageFile.path;
  } else {
    // Handle other platforms if necessary
    return imageFile.path;
  }
}

Future<String> getPathAndroid13(File imageFile, String filename) async {
  if (await Permission.photos.request().isGranted) {
    FileLogger.log(
      "Photos permission granted, using original path: ${imageFile.path}",
    );
    return imageFile.path;
  } else {
    FileLogger.log(
      "Photos permission denied, falling back to app's storage directory",
    );
    return await getDocumentsDir(imageFile, filename);
  }
}

Future<String> getPathAndroid12(File imageFile, String filename) async {
  if (await Permission.storage.request().isGranted) {
    FileLogger.log(
        "Storage permission granted, using original path: ${imageFile.path}");
    return imageFile.path;
  } else {
    FileLogger.log(
        "Storage permission denied, falling back to app's storage directory");
    return await getDocumentsDir(imageFile, filename);
  }
}

Future<String> getDocumentsDir(File imageFile, String filename) async {
  final appDir = await getApplicationDocumentsDirectory();
  return (await imageFile.copy('${appDir.path}/$filename')).path;
}
