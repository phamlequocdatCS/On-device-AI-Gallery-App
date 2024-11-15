import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static const String _fileName = 'app_log.txt';
  static File? _logFile;

  static Future<void> initialize() async {
    if (_logFile != null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_fileName');

      // Clear the log file on app start
      await _logFile!.writeAsString('');

      log('FileLogger initialized');
    } catch (e) {
      print('Error initializing FileLogger: $e');
    }
  }

  static Future<void> log(String message) async {
    if (_logFile == null) {
      print('FileLogger not initialized');
      return;
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '$timestamp: $message\n';

      await _logFile!.writeAsString(logMessage, mode: FileMode.append);

      // Also print to console in debug mode
      if (kDebugMode) {
        print(logMessage);
      }
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }

  static Future<String> getLogContents() async {
    if (_logFile == null) {
      return 'FileLogger not initialized';
    }

    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
}
