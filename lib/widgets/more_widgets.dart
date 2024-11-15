import 'dart:io';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../database.dart';
import '../utility/file_utils.dart';

class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Future<File>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = getFile(widget.imagePath);
  }

  @override
  void didUpdateWidget(covariant ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      setState(() {
        _fileFuture = getFile(widget.imagePath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Icon(Icons.error));
        } else if (snapshot.hasData) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        } else {
          return const Center(child: Icon(Icons.error));
        }
      },
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final ImageMetadata metadata;

  const FullScreenImage({
    super.key,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ImageMetadataAlert(metadata: metadata),
              );
            },
          ),
        ],
      ),
      body: Hero(
        tag: metadata.hash,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 10.0,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.file(
              File(metadata.filePath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}

class ImageMetadataAlert extends StatelessWidget {
  const ImageMetadataAlert({
    super.key,
    required this.metadata,
  });

  final ImageMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Image Information'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filename: ${metadata.filename}'),
          Text('File Size: ${metadata.fileSize}'),
          Text('File Resolution: ${metadata.fileResolution}'),
          Text('Category: ${metadata.categories.toString()}'),
          Text('Time of Creation: ${metadata.timeOfCreation}'),
          Text('File path: ${metadata.filePath}'),
          Text('SHA256: ${metadata.hash}'),
          Text('Tagging Model: ${metadata.modelName}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount getCustomizatbleGrid(
  bool isPortrait,
  int columns,
) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: isPortrait ? columns : columns + 1,
    childAspectRatio: 1,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  );
}

PopupMenuItem<T> getPopupMenuItem<T>(
    T currentValue, T optionValue, String Function(T) getName,
    {IconData? icon}) {
  return PopupMenuItem(
    value: optionValue,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(getName(optionValue)),
        if (currentValue == optionValue) Icon(icon ?? Icons.check),
      ],
    ),
  );
}

PopupMenuItem<int> getColumnOption(
  int currentColumns,
  int optionColumns,
  String text,
) {
  return getPopupMenuItem(
    currentColumns,
    optionColumns,
    (value) => text,
  );
}

PopupMenuItem<Models> getModelOption(Models currentModel, Models optionModel) {
  return getPopupMenuItem(
    currentModel,
    optionModel,
    GalleryModelManager.getModelName,
  );
}

PopupMenuItem<SearchTypes> getSearchTypeOption(
  SearchTypes currentType,
  SearchTypes optionType,
) {
  return PopupMenuItem(
    value: optionType,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            SearchTypeManager.getSearchTypeName(optionType),
          ),
          const SizedBox(width: 8.0),
          Icon(
            getSearchTypeIcon(optionType),
          ),
        ],
      ),
    ),
  );
}

IconData getSearchTypeIcon(SearchTypes type) {
  switch (type) {
    case SearchTypes.fileName:
      return Icons.file_copy;
    case SearchTypes.category:
      return Icons.category;
    case SearchTypes.semantic:
      return Icons.question_mark;
    default:
      return Icons.help;
  }
}

Future<bool> showGenericConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return ConfirmAlert(
            title: title,
            content: content,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
          );
        },
      ) ??
      false;
}

class ConfirmAlert extends StatelessWidget {
  final String title;
  final String cancelLabel;
  final String content;
  final String confirmLabel;

  const ConfirmAlert({
    super.key,
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          child: Text(cancelLabel),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        TextButton(
          child: Text(confirmLabel),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}

class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({super.key, this.message = 'Thinking...'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class RichTextCounterLimit extends StatelessWidget {
  const RichTextCounterLimit({
    super.key,
    required this.tokenizedLength,
    required this.isExceeded,
    required this.fontSize,
    required this.color,
    this.maxLength = 75,
  });

  final int tokenizedLength;
  final bool isExceeded;
  final double fontSize;
  final Color color;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$tokenizedLength',
            style: TextStyle(
              color: isExceeded ? Colors.red : color,
              fontSize: fontSize,
            ),
          ),
          TextSpan(
            text: '/$maxLength',
            style: TextStyle(color: color, fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}
