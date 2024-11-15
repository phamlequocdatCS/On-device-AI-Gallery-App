import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart';

import '../../constants.dart';
import '../../utility/math_utils.dart';

import 'onnx_utils.dart';
import "../../transformers_dart/tokenizer.dart";

Future<List<double>> embedText(
  String inputText,
  PreTrainedTokenizer tokenizer,
  OrtRunOptions runOptions,
  OrtSession session,
) async {
  List<double> textEmbed;

  List<int> tokenizedText = tokenizer.encodeText(inputText);
  List<List<int>> inputTokens = [tokenizedText];
  final inputOrt = OrtValueTensor.createTensorWithDataList(inputTokens);
  final inputs = {'input_ids': inputOrt};
  final outputs = session.run(runOptions, inputs);
  inputOrt.release();
  List outFloats = outputs[0]?.value as List;
  // Close resources
  textEmbed = normalizeDoubles(outFloats[0]);

  return textEmbed;
}

Future<List<double>> embedImage(
  Image imageFile,
  int width,
  int height,
  OrtSession session,
  OrtRunOptions runOptions,
) async {
  List<double> imageEmbed;
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

  final inputs = {'pixel_values': inputOrt};
  final outputs = session.run(runOptions, inputs);
  inputOrt.release();

  List outFloats = outputs[0]?.value as List;
  imageEmbed = normalizeDoubles(outFloats[0]);

  return imageEmbed;
}

Future<List<double>> embedImageE2E(Image imageFile) async {
  // Init environment
  OrtEnv.instance.init();
  final runOptions = OrtRunOptions();
  final rawAssetFile = await rootBundle.load(SemanticModelManager.img2vecPath);
  OrtSession session = await createSessionInBackground(
    rawAssetFile.buffer.asUint8List(),
  );
  return embedImage(imageFile, 224, 224, session, runOptions);
}

Future<List<List<double>>> batchedImageEmbed(List<Image> images,
    {int batchSize = 4}) async {
  // Init environment
  OrtEnv.instance.init();
  final runOptions = OrtRunOptions();
  final rawAssetFile = await rootBundle.load(SemanticModelManager.img2vecPath);
  OrtSession session = await createSessionInBackground(
    rawAssetFile.buffer.asUint8List(),
  );

  const int width = 224;
  const int height = 224;

  List<List<double>> allImageEmbeds = [];

  for (int i = 0; i < images.length; i += batchSize) {
    int end = (i + batchSize < images.length) ? i + batchSize : images.length;
    List<Image> batch = images.sublist(i, end);

    // Preprocess batch of images
    List<List<double>> batchedRgbFloats = await Future.wait(
      batch.map(
        (image) => imageToFloatTensor(image, width: width, height: height),
      ),
    );

    // Create a single batched tensor
    List<double> flattenedRgbFloats = batchedRgbFloats
        .expand(
          (i) => i,
        )
        .toList();
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(flattenedRgbFloats),
      [batch.length, 3, width, height],
    );

    final inputs = {'pixel_values': inputOrt};
    final outputs = session.run(runOptions, inputs);
    inputOrt.release();

    List outFloats = outputs[0]?.value as List;

    for (int j = 0; j < batch.length; j++) {
      allImageEmbeds.add(normalizeDoubles(outFloats[j]));
    }
  }

  return allImageEmbeds;
}
