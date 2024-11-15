import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart';
import 'package:path/path.dart';

import '../ai_run/inference_mlkit.dart';
import '../ai_run/onnx/inference_onnx.dart';
import '../ai_run/onnx/inference_onnx_semantic.dart';
import '../ai_run/tflite/inference_tflite.dart';
import '../constants.dart';
import 'file_utils.dart';
import 'thumbnail_generator.dart';

class IntermediateResults {
  List<String> listFilenames;
  List<String> listFilePaths;
  List<String> listFileSizes;
  List<DateTime> listTimeOfCreate;
  List<Image> listImages;
  List<String> listHashes;
  List<String> listResolutions;
  List<List<double>> listImageEmbeds;
  List<String?> listThumbnailPaths;

  IntermediateResults({
    required this.listFilenames,
    required this.listFilePaths,
    required this.listFileSizes,
    required this.listTimeOfCreate,
    required this.listImages,
    required this.listHashes,
    required this.listResolutions,
    required this.listImageEmbeds,
    required this.listThumbnailPaths,
  });
}

Future<List<List<String>>> getListCategories(
    Architectures arch,
    List<List<String>> listCategories,
    List<File> files,
    Models currentModel,
    IntermediateResults results) async {
  switch (arch) {
    case Architectures.MLKIT:
      listCategories = await getMLKIT(files);
      break;
    case Architectures.TFLITE:
      listCategories = await getTFLite(currentModel, results);
      break;
    default:
      listCategories = await getONNX(results, currentModel);
      break;
  }
  return listCategories;
}

Future<IntermediateResults> getBatchedONNX(
  List<File> imageFiles,
  Models currentModel,
) async {
  List<Future<Map<String, dynamic>>> fileFutures =
      imageFiles.map((imageFile) async {
    final filename = basename(imageFile.path);
    final filePath = await getFilePath(imageFile, filename);
    final fileSize = await getFileSizeMB(imageFile);
    final timeOfCreation = imageFile.lastModifiedSync();

    return {
      'filename': filename,
      'filePath': filePath,
      'filesize': fileSize,
      'toc': timeOfCreation
    };
  }).toList();

  List<Map<String, dynamic>> processedFilesData =
      await Future.wait(fileFutures);

  List<String> listFileNames = processedFilesData
      .map(
        (data) => data['filename'] as String,
      )
      .toList();
  List<String> listFilePaths = processedFilesData
      .map(
        (data) => data['filePath'] as String,
      )
      .toList();
  List<String> listFileSizes = processedFilesData
      .map(
        (data) => data['filesize'] as String,
      )
      .toList();
  List<DateTime> listToCs = processedFilesData
      .map(
        (data) => data['toc'] as DateTime,
      )
      .toList();

  // Read all image bytes in parallel
  List<Uint8List> listBytes = await Future.wait(
    imageFiles.map((imageFile) => imageFile.readAsBytes()),
  );

  // Process images: decode, hash, and calculate resolution in parallel
  List<Future<Map<String, dynamic>>> futures = listBytes.map((bytes) async {
    final image = decodeImage(bytes)!;
    final hash = sha256.convert(bytes).toString();
    final resolution = '${image.width}x${image.height}';
    return {'image': image, 'hash': hash, 'resolution': resolution};
  }).toList();

  // Wait for all image processing to complete
  List<Map<String, dynamic>> processedImages = await Future.wait(futures);

  // Extract the results: images, hashes, and resolutions
  List<Image> listImages = processedImages
      .map(
        (data) => data['image'] as Image,
      )
      .toList();
  List<String> listHashes = processedImages
      .map(
        (data) => data['hash'] as String,
      )
      .toList();
  List<String> listResolutions = processedImages
      .map(
        (data) => data['resolution'] as String,
      )
      .toList();

  // Perform ONNX embedding in parallel
  final imageEmbedsFuture = batchedImageEmbed(listImages);

  List<List<double>> listImageEmbeds = await imageEmbedsFuture;

  List<String?> listThumbnailPaths = await getThumbnailPathList(imageFiles);

  return IntermediateResults(
    listFilenames: listFileNames,
    listFilePaths: listFilePaths,
    listFileSizes: listFileSizes,
    listTimeOfCreate: listToCs,
    listImages: listImages,
    listHashes: listHashes,
    listResolutions: listResolutions,
    listImageEmbeds: listImageEmbeds,
    listThumbnailPaths: listThumbnailPaths,
  );
}

Future<List<List<String>>> getONNX(
  IntermediateResults results,
  Models currentModel,
) async {
  List<List<String>> listCategories = await batchedInferenceONNX(
    results.listImages,
    currentModel,
    batchSize: 4,
  );
  return listCategories;
}

Future<List<List<String>>> getTFLite(
    Models currentModel, IntermediateResults results,
    {int batchSize = 1}) async {
  ImageClassificationHelper imageClassificationHelper =
      ImageClassificationHelper(isV3: currentModel == Models.V3);
  await imageClassificationHelper.initHelper();

  Future<List<List<String>>> processBatch(List<Image> batchFiles) async {
    List<Future<List<String>>> labelFutures = batchFiles.map((imageFile) async {
      List<String> categories = [];
      await singleTFLITEInference(
        imageFile,
        categories,
        imageClassificationHelper,
      );
      return categories;
    }).toList();

    // Wait for the batch to complete
    return await Future.wait(labelFutures);
  }

  List<List<String>> listCategories = [];

  await getBatchedResults(
    results.listImages,
    batchSize,
    processBatch,
    listCategories,
  );

  await imageClassificationHelper.close();

  return listCategories;
}

Future<List<List<String>>> getMLKIT(List<File> imageFiles,
    {int batchSize = 1}) async {
  ImageLabeler imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  // Helper function to process a batch of files
  Future<List<List<String>>> processBatch(List<File> batchFiles) async {
    List<Future<List<String>>> labelFutures = batchFiles.map((imageFile) async {
      List<String> categories = [];
      await singleMLKITInference(imageFile, categories, imageLabeler);
      return categories;
    }).toList();

    // Wait for the batch to complete
    return await Future.wait(labelFutures);
  }

  List<List<String>> listCategories = [];

  await getBatchedResults(imageFiles, batchSize, processBatch, listCategories);

  imageLabeler.close();

  return listCategories;
}

Future<void> getBatchedResults<T>(
  List<T> inputItems,
  int batchSize,
  Future<List<List<String>>> Function(List<T> batchItems) processBatch,
  List<List<String>> listCategories,
) async {
  for (int i = 0; i < inputItems.length; i += batchSize) {
    int end =
        (i + batchSize < inputItems.length) ? i + batchSize : inputItems.length;
    List<T> batchItems = inputItems.sublist(i, end);

    List<List<String>> batchResult = await processBatch(batchItems);
    listCategories.addAll(batchResult);
  }
}
