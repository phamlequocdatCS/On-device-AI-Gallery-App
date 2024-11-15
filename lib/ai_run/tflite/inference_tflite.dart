import 'dart:io';
import 'dart:isolate';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';

import '../../constants.dart';
import '../../misc/file_logger.dart';
import '../../misc/labels.dart';
import 'isolate_inference.dart';

Future<List<String>> inferenceTFLITE(
  Image imageFile,
  Models currentModel,
) async {
  bool isV3 = currentModel == Models.V3;
  late final ImageClassificationHelper imageClassificationHelper;
  List<String> categories = [];

  try {
    // Init model
    imageClassificationHelper = ImageClassificationHelper(isV3: isV3);
    await imageClassificationHelper.initHelper();

    await singleTFLITEInference(
      imageFile,
      categories,
      imageClassificationHelper,
    );
  } finally {
    imageClassificationHelper.close();
  }
  return categories;
}

Future<void> singleTFLITEInference(
  Image image,
  List<String> categories,
  ImageClassificationHelper imageClassificationHelper,
) async {
  // Inference
  Map<String, double> classification =
      await imageClassificationHelper.inferenceImage(image);

  List<String> keys = classification.keys.toList();
  categories.addAll(keys.take(10));
}

class ImageClassificationHelper {
  late final Interpreter interpreter;
  late final List<String> labels;
  late final IsolateInference isolateInference;
  late Tensor inputTensor;
  late Tensor outputTensor;
  late List<int> inputShape;
  late List<int> outputShape;
  bool isV3;

  ImageClassificationHelper({required this.isV3});

  // Load model
  Future<void> _loadModel() async {
    final options = InterpreterOptions();
    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    }
    String modelPath = GalleryModelManager.getMobileNetPath(isV3);
    interpreter = await Interpreter.fromAsset(modelPath, options: options);
    inputTensor = interpreter.getInputTensors().first;
    outputTensor = interpreter.getOutputTensors().first;
    inputShape = interpreter.getInputTensor(0).shape;
    outputShape = interpreter.getOutputTensor(0).shape;
    FileLogger.log('Interpreter loaded successfully');
  }

  Future<void> _loadLabels() async {
    labels = mobileNetTFLiteId2Label;
  }

  Future<void> initHelper() async {
    await _loadLabels();
    await _loadModel();
    isolateInference = IsolateInference(isV3: isV3);
    await isolateInference.start();
  }

  Future<Map<String, double>> inferenceImage(Image image) async {
    final inferenceModel = InferenceModel(
      image,
      interpreter.address,
      labels,
      inputShape,
      outputShape,
      isV3,
    );
    final responsePort = ReceivePort();
    inferenceModel.responsePort = responsePort.sendPort;
    isolateInference.sendPort.send(inferenceModel);
    final results = await responsePort.first as Map<String, double>;
    return results;
  }

  Future<void> close() async {
    isolateInference.close();
  }
}
