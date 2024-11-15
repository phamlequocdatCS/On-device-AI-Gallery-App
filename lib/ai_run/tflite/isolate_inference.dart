/* Modified September 28 2024
 *
 * Original notice:
 *  Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *  
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  
 *              http://www.apache.org/licenses/LICENSE-2.0
 *  
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

import 'dart:isolate';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class IsolateInference {
  static const String _debugName = "TFLITE_INFERENCE";
  final ReceivePort _receivePort = ReceivePort();
  late Isolate _isolate;
  late SendPort _sendPort;
  final bool isV3;

  IsolateInference({required this.isV3});

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: _debugName,
    );
    _sendPort = await _receivePort.first;
  }

  Future<void> close() async {
    _isolate.kill();
    _receivePort.close();
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final InferenceModel isolateModel in port) {
      image_lib.Image? img;
      img = isolateModel.image;

      // resize original image to match model shape.
      image_lib.Image imageInput = image_lib.copyResize(
        img,
        width: isolateModel.inputShape[1],
        height: isolateModel.inputShape[2],
      );

      List imageMatrix;

      if (isolateModel.isV3) {
        imageMatrix = List.generate(
          imageInput.height,
          (y) => List.generate(
            imageInput.width,
            (x) {
              final pixel = imageInput.getPixel(x, y);
              // Normalize the pixel values to [0, 1] range
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        );
      } else {
        imageMatrix = List.generate(
          imageInput.height,
          (y) => List.generate(
            imageInput.width,
            (x) {
              final pixel = imageInput.getPixel(x, y);
              return [pixel.r, pixel.g, pixel.b];
            },
          ),
        );
      }

      // Set tensor input [1, 224, 224, 3]
      final input = [imageMatrix];
      // Set tensor output [1, 1001]
      final output = isolateModel.isV3
          ? [List<double>.filled(isolateModel.outputShape[1], 0.0)]
          : [List<int>.filled(isolateModel.outputShape[1], 0)];

      // // Run inference
      Interpreter interpreter =
          Interpreter.fromAddress(isolateModel.interpreterAddress);
      interpreter.run(input, output);
      // Get first output tensor
      final result = output.first;
      var maxScore = isolateModel.isV3
          ? (result as List<double>).reduce((a, b) => a > b ? a : b)
          : (result as List<int>).reduce((a, b) => a > b ? a : b);
      // Set classification map {label: points}
      var classification = <String, double>{};
      for (var i = 0; i < result.length; i++) {
        if (result[i] > 0.1) {
          // Set label: points
          classification[isolateModel.labels[i]] =
              result[i].toDouble() / maxScore.toDouble();
        }
      }

      // Sort the classification map by its values
      var sortedEntries = classification.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      var sortedClassification = Map.fromEntries(sortedEntries);

      isolateModel.responsePort.send(sortedClassification);
    }
  }
}

class InferenceModel {
  image_lib.Image image;
  int interpreterAddress;
  List<String> labels;
  List<int> inputShape;
  List<int> outputShape;
  late SendPort responsePort;
  bool isV3;

  InferenceModel(
    this.image,
    this.interpreterAddress,
    this.labels,
    this.inputShape,
    this.outputShape,
    this.isV3,
  );
}
