import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';

import 'constants.dart';
import 'database.dart';
import 'utility/image_processor_utils.dart';
import 'utility/utils.dart';
import 'utility/file_utils.dart';

Future<XFile?> pickFile(ImageSource source) async {
  final ImagePicker picker = ImagePicker();
  final XFile? pickedFile = await picker.pickImage(source: source);
  return pickedFile;
}

class ImageProcessingSystem {
  final Box<ImageMetadata> imageMetadataBox;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final Function(bool) setLoading;

  ImageProcessingSystem(
    this.imageMetadataBox,
    this.setLoading,
    this.scaffoldMessengerKey,
  );

  Future<void> addSingleImage(
    Models currentModel,
  ) async {
    XFile? pickedFile = await pickFile(ImageSource.gallery);
    await pickImageProcess(
      pickedFile,
      currentModel,
    );
  }

  Future<void> addMultipleImages(
    Models currentModel,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      List<File> validFiles = [];
      validFiles.addAll(result.files.map((file) {
        return File(file.path!);
      }));
      await _processAndSaveImages(validFiles, currentModel);
      showSnackBar(
        '${validFiles.length} images added successfully',
        scaffoldMessengerKey,
      );
    }
  }

  Future<void> takePhoto(
    Models currentModel,
  ) async {
    if (Platform.isAndroid) {
      await pickImageProcess(
        await pickFile(ImageSource.camera),
        currentModel,
      );
    } else {
      showSnackBar(
        'Camera capture is only supported on Android',
        scaffoldMessengerKey,
      );
    }
  }

  Future<void> pickImageProcess(
    XFile? pickedFile,
    Models currentModel,
  ) async {
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _processAndSaveImages([imageFile], currentModel);
      showSnackBar('Photo added successfully', scaffoldMessengerKey);
    }
  }

  Future<void> importImagesFromFolder(
    Models currentModel,
  ) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      List<File> validFiles = getValidFiles(selectedDirectory);

      await _processAndSaveImages(validFiles, currentModel);
      showSnackBar(
        '${validFiles.length} images added from folder',
        scaffoldMessengerKey,
      );
    }
  }

  Future<void> _processAndSaveImages(
    List<File> files,
    Models currentModel,
  ) async {
    setLoading(true);

    IntermediateResults results = await getBatchedONNX(files, currentModel);

    List<List<String>> listCategories = [];
    listCategories = await getListCategories(
      GalleryModelManager.getArchitecture(currentModel),
      listCategories,
      files,
      currentModel,
      results,
    );

    for (var i = 0; i < files.length; i++) {
      final metadata = ImageMetadata(
        filename: results.listFilenames[i],
        fileSize: results.listFileSizes[i],
        fileResolution: results.listResolutions[i],
        categories: listCategories[i],
        timeOfCreation: results.listTimeOfCreate[i],
        filePath: results.listFilePaths[i],
        originalFilePath: files[i].path,
        hash: results.listHashes[i],
        modelName: GalleryModelManager.getModelName(currentModel),
        imageEmbedding: results.listImageEmbeds[i],
        thumbnailPath: results.listThumbnailPaths[i],
      );

      await imageMetadataBox.put(results.listFilenames[i], metadata);
    }

    setLoading(false);
  }
}
