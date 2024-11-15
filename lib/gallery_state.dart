import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'database.dart';
import 'constants.dart';
import 'image_processor.dart';

import 'ai_run/onnx/inference_onnx_semantic.dart';
import 'ai_run/onnx/onnx_utils.dart';

import 'misc/file_logger.dart';
import 'transformers_dart/tokenizer.dart';
import 'utility/utils.dart';
import 'utility/hive_utils.dart';
import 'utility/math_utils.dart';

class GalleryState with ChangeNotifier {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  late Box<ImageMetadata> imageMetadataBox =
      Hive.box<ImageMetadata>('imageMetadata');
  late ImageProcessingSystem imageProcessingSystem = ImageProcessingSystem(
    imageMetadataBox,
    setLoading,
    scaffoldMessengerKey,
  );
  List<ImageMetadata> filteredList = [];
  int columns = 3;
  Models currentModel = Models.ONNX_MVIT_X_S;
  SearchTypes currentSearch = SearchTypes.category;
  bool isLoading = false;

  PreTrainedTokenizer tokenizer = PreTrainedTokenizer();
  OrtSession? textEmbedSession;
  OrtSessionOptions? textEmbedSessionOptions;
  OrtRunOptions? runOptions;

  GalleryState(this.scaffoldMessengerKey) {
    _fetchImages();
    _initTokenizer();
  }

  void _initTokenizer() async {
    setLoading(true);
    await tokenizer.readFromFiles(
      SemanticModelManager.jsonPath,
      SemanticModelManager.configPath,
    );
    setLoading(false);
  }

  void _fetchImages() {
    filteredList = imageMetadataBox.values.toList();
    notifyListeners();
  }

  void setColumns(int value) {
    columns = value;
    notifyListeners();
  }

  void setModel(Models model) {
    currentModel = model;
    notifyListeners();
  }

  void setSearchType(SearchTypes type) async {
    currentSearch = type;
    if (currentSearch == SearchTypes.semantic) {
      loadTextEmbedModel();
    } else {
      releaseTextEmbedModel();
    }
    notifyListeners();
  }

  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  void filterImages(String query) {
    if (query.isEmpty || currentSearch == SearchTypes.semantic) {
      _fetchImages();
    } else {
      filteredList = imageMetadataBox.values.where((metadata) {
        switch (currentSearch) {
          case SearchTypes.fileName:
            return matchesQuery(metadata.filename, query);
          case SearchTypes.category:
          default:
            return matchesQuery(metadata.categories.toString(), query);
        }
      }).toList();
      notifyListeners();
    }
  }

  Future<bool> forceWipeDatabase() async {
    try {
      // Clear data
      await imageMetadataBox.clear();
      await Hive.deleteBoxFromDisk('imageMetadata');

      // Clear thumbnail
      await forceWipeThumbnails();

      // Init and open Box
      await openHiveBox();
      imageMetadataBox = Hive.box<ImageMetadata>('imageMetadata');
      imageProcessingSystem = ImageProcessingSystem(
        imageMetadataBox,
        setLoading,
        scaffoldMessengerKey,
      );
      _fetchImages();
      FileLogger.log('Database wiped successfully');

      return true;
    } catch (e) {
      FileLogger.log('Error wiping database: $e');
      return false;
    }
  }

  Future<void> addSingleImage() async {
    await imageProcessingSystem.addSingleImage(
      currentModel,
    );
    _fetchImages();
  }

  Future<void> takePhoto() async {
    await imageProcessingSystem.takePhoto(
      currentModel,
    );
    _fetchImages();
  }

  Future<void> addMultipleImages() async {
    await imageProcessingSystem.addMultipleImages(
      currentModel,
    );
    _fetchImages();
  }

  Future<void> importImagesFromFolder() async {
    await imageProcessingSystem.importImagesFromFolder(
      currentModel,
    );
    _fetchImages();
  }

  Future<void> searchSemantic(String query) async {
    if (textEmbedSession != null &&
        textEmbedSessionOptions != null &&
        query.isNotEmpty) {
      List<double> textEmbedding = await embedText(
        query,
        tokenizer,
        runOptions!,
        textEmbedSession!,
      );
      List<List<double>> imageEmbeds = [];
      List<int> embeddingIndices = [];
      List<ImageMetadata> results = [];

      for (int i = 0; i < imageMetadataBox.values.length; i++) {
        var metadata = imageMetadataBox.values.elementAt(i);
        if (metadata.imageEmbedding != null) {
          imageEmbeds.add(metadata.imageEmbedding!);
          embeddingIndices.add(i);
        }
      }

      List<double> probabilities =
          computeProbabilities(textEmbedding, imageEmbeds);

      List<int> topIndices = topKIndices(probabilities, 10);

      for (int i in topIndices) {
        if (probabilities[i] > 0.1) {
          int originalIndex = embeddingIndices[i];
          results.add(imageMetadataBox.values.elementAt(originalIndex));
        }
      }

      print(probabilities.toString());

      filteredList = results;
    } else {
      filteredList = imageMetadataBox.values.toList();
    }
    notifyListeners();
  }

  Future<void> loadTextEmbedModel() async {
    if (runOptions == null &&
        textEmbedSession == null &&
        textEmbedSessionOptions == null) {
      try {
        setLoading(true);
        runOptions = OrtRunOptions();
        final rawAssetFile = await rootBundle.load(
          SemanticModelManager.txt2vecPath,
        );
        textEmbedSessionOptions = OrtSessionOptions();
        textEmbedSession = await createSessionInBackground(
          rawAssetFile.buffer.asUint8List(),
        );

        FileLogger.log("Loading text model complete");
      } catch (e, stackTrace) {
        FileLogger.log("Error loading text model: $e");
        FileLogger.log("Stack trace: $stackTrace");
        // Revert to a different search type
        setSearchType(SearchTypes.category);
      } finally {
        setLoading(false);
      }
    } else {
      FileLogger.log("Text model already loaded");
    }
  }

  Future<void> releaseTextEmbedModel() async {
    if (runOptions != null ||
        textEmbedSession != null ||
        textEmbedSessionOptions != null) {
      try {
        runOptions?.release();
        textEmbedSessionOptions?.release();
        textEmbedSession?.release();
        runOptions = null;
        textEmbedSession = null;
        textEmbedSessionOptions = null;
        FileLogger.log("Released text model");
      } catch (e) {
        FileLogger.log("Error releasing text model: $e");
      }
    }
  }
}
