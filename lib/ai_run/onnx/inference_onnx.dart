import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart';

import '../../constants.dart';
import '../../misc/file_logger.dart';
import '../../misc/labels.dart';
import '../../utility/math_utils.dart';
import 'onnx_utils.dart';

// https://github.com/andreidiaconu/onnxflutterplay

Future<List<String>> inferenceONNX(
  Image imageFile,
  Models currentModel,
) async {
  // Init environment
  OrtEnv.instance.init();
  final sessionOptions = OrtSessionOptions();
  final runOptions = OrtRunOptions();
  const int width = 256;
  const int height = 256;
  List<String> categories = [];

  OrtSession? session;

  try {
    // Load model
    final rawAssetFile = await rootBundle.load(
      GalleryModelManager.getONNXMobileViTPath(currentModel),
    );
    session = OrtSession.fromBuffer(
      rawAssetFile.buffer.asUint8List(),
      sessionOptions,
    );
    await singleONNXInference(
      imageFile,
      categories,
      width,
      height,
      session,
      runOptions,
    );
  } finally {
    // Close resources
    session?.release();
    runOptions.release();
    sessionOptions.release();
    OrtEnv.instance.release();
  }

  return categories;
}

Future<void> singleONNXInference(
  Image imageFile,
  List<String> categories,
  int width,
  int height,
  OrtSession session,
  OrtRunOptions runOptions,
) async {
  // Preprocess image
  final rgbFloats = await imageToFloatTensor(
    imageFile,
    width: width,
    height: height,
  );
  final inputOrt = OrtValueTensor.createTensorWithDataList(
    Float32List.fromList(rgbFloats),
    [1, 3, width, height],
  );

  // Get the name from Natron Model viewer
  final inputs = {'pixel_values': inputOrt};
  // Run model
  final outputs = session.run(runOptions, inputs);
  // Close resources
  inputOrt.release();

  // Get output values
  List outFloats = outputs[0]?.value as List;
  List<double> outLogits = outFloats[0];

  // Convert to probability (not needed?)
  List<double> probabilities = softmax(outLogits);
  // Get top 10 classes
  List<int> topIndices = topKIndices(probabilities, 10);

  categories.addAll(topIndices.map((idx) => mobilenetONNXid2label[idx]));
}

Future<List<List<String>>> batchedInferenceONNX(
    List<Image> images, Models currentModel,
    {int batchSize = 4}) async {
  // Init environment
  OrtEnv.instance.init();
  final sessionOptions = OrtSessionOptions();
  final runOptions = OrtRunOptions();
  const int width = 256;
  const int height = 256;
  List<List<String>> allCategories = [];

  OrtSession? session;

  try {
    // Load model
    final rawAssetFile = await rootBundle.load(
      GalleryModelManager.getONNXMobileViTPath(currentModel),
    );

    session = await createSessionInBackground(
      rawAssetFile.buffer.asUint8List(),
    );
    FileLogger.log("Loaded Category ONNX session");

    for (int i = 0; i < images.length; i += batchSize) {
      int end = (i + batchSize < images.length) ? i + batchSize : images.length;
      List<Image> batch = images.sublist(i, end);

      List<List<String>> batchCategories = await _processBatchInBackground(
        batch,
        width,
        height,
        session,
        runOptions,
      );
      allCategories.addAll(batchCategories);
      FileLogger.log("Computed $end/${images.length}");
    }
  } finally {
    // Close resources
    session?.release();
    runOptions.release();
    sessionOptions.release();
    OrtEnv.instance.release();
  }

  return allCategories;
}

Future<List<List<String>>> _processBatchInBackground(List<Image> batch,
    int width, int height, OrtSession session, OrtRunOptions runOptions) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_runBatchedInferenceIsolate, [
    batch,
    width,
    height,
    session,
    runOptions,
    receivePort.sendPort,
  ]);

  return await receivePort.first as List<List<String>>;
}

void _runBatchedInferenceIsolate(List<dynamic> args) async {
  List<Image> images = args[0];
  int width = args[1];
  int height = args[2];
  OrtSession session = args[3];
  OrtRunOptions runOptions = args[4];
  SendPort sendPort = args[5];

  List<List<String>> batchCategories = [];

  // Preprocess images
  List<List<double>> batchedRgbFloats = await Future.wait(
    images.map(
      (image) => imageToFloatTensor(
        image,
        width: width,
        height: height,
      ),
    ),
  );

  // Create a single batched tensor
  List<double> flattenedRgbFloats = batchedRgbFloats.expand((i) => i).toList();
  final inputOrt = OrtValueTensor.createTensorWithDataList(
    Float32List.fromList(flattenedRgbFloats),
    [images.length, 3, width, height],
  );

  // Run inference
  final inputs = {'pixel_values': inputOrt};
  final outputs = session.run(runOptions, inputs);

  // Get output values and categories for each image
  List outFloats = outputs[0]?.value as List;
  for (int i = 0; i < images.length; i++) {
    List<double> outLogits = outFloats[i];
    List<double> probabilities = softmax(outLogits);
    List<int> topIndices = topKIndices(probabilities, 10);
    List<String> categories =
        topIndices.map((idx) => mobilenetONNXid2label[idx]).toList();
    batchCategories.add(categories);
  }

  inputOrt.release();

  // Send results back to the main isolate
  sendPort.send(batchCategories);
}
