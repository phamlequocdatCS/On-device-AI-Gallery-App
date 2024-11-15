import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gallery_state.dart';

class AddImageOptions extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const AddImageOptions({
    super.key,
    required this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    final galleryState = Provider.of<GalleryState>(context, listen: false);

    void addSingleImage() {
      Navigator.pop(context);
      galleryState.addSingleImage();
    }

    void takePhoto() {
      Navigator.pop(context);
      galleryState.takePhoto();
    }

    void addMultipleImages() {
      Navigator.pop(context);
      galleryState.addMultipleImages();
    }

    void importImagesFromFolder() {
      Navigator.pop(context);
      galleryState.importImagesFromFolder();
    }

    return SafeArea(
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick a single image'),
                onTap: addSingleImage,
              ),
              if (Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: takePhoto,
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick multiple images'),
                onTap: addMultipleImages,
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Import images from a folder'),
                onTap: importImagesFromFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
