import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../misc/file_logger.dart';

Future<List<double>> imageToFloatTensor(Image image,
    {int width = 255, int height = 255}) {
  final resizedImage = copyResize(image, width: width, height: height);
  final rgbImage = copyRotate(resizedImage, angle: 0);

  final floats = Float32List(3 * width * height);
  int i = 0;
  for (int y = 0; y < width; y++) {
    for (int x = 0; x < height; x++) {
      final pixel = rgbImage.getPixel(x, y);
      floats[i] = pixel.r / 255.0;
      floats[i + width * height] = pixel.g / 255.0;
      floats[i + 2 * width * height] = pixel.b / 255.0;
      i++;
    }
  }

  return Future.value(floats.toList());
}

Future<Image> loadImageFromAsset(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return decodeImage(data.buffer.asUint8List())!;
}

Future<OrtSession> createSessionInBackground(Uint8List modelData) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(createOrtSession, [modelData, receivePort.sendPort]);
  final result = await receivePort.first as OrtSession;
  FileLogger.log("Load ONNX Model Session success");
  return result;
}

void createOrtSession(List<dynamic> args) {
  final modelData = args[0] as Uint8List;
  final sendPort = args[1] as SendPort;

  final textEmbedSessionOptions = OrtSessionOptions();
  final session = OrtSession.fromBuffer(modelData, textEmbedSessionOptions);

  sendPort.send(session);
}
