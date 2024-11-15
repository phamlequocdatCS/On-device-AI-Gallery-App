import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

Future<List<String>> inferenceMLKIT(File imageFile) async {
  late final ImageLabeler imageLabeler;
  List<String> categories = [];

  try {
    // Init model
    imageLabeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7));

    await singleMLKITInference(imageFile, categories, imageLabeler);
  } finally {
    imageLabeler.close();
  }

  return categories;
}

Future<void> singleMLKITInference(
  File imageFile,
  List<String> categories,
  ImageLabeler imageLabeler,
) async {
  final InputImage inputImage = InputImage.fromFile(imageFile);

  final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);

  for (ImageLabel label in labels) {
    categories.add(label.label);
  }
}
