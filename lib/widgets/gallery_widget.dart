import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../database.dart';
import '../gallery_state.dart';
import '../utility/math_utils.dart';
import 'more_widgets.dart';

class GalleryWidget extends StatelessWidget {
  final void Function(BuildContext, ImageMetadata) onThumbnailTapped;

  const GalleryWidget({
    super.key,
    required this.onThumbnailTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryState>(
      builder: (context, state, _) {
        return Expanded(
          child: ValueListenableBuilder(
            valueListenable: state.imageMetadataBox.listenable(),
            builder: (context, Box<ImageMetadata> box, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: state.columns == -1
                          ? calculateCrossAxisCount(constraints.maxWidth, 200)
                          : state.columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredList.length,
                    itemBuilder: (context, index) {
                      final metadata = state.filteredList[index];
                      return GalleryItem(
                        metadata: metadata,
                        onTap: onThumbnailTapped,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class GalleryItem extends StatelessWidget {
  final ImageMetadata metadata;
  final Function(BuildContext, ImageMetadata) onTap;

  const GalleryItem({
    super.key,
    required this.metadata,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(context, metadata),
      child: ThumbnailImage(
        imagePath: metadata.thumbnailPath ?? metadata.filePath,
      ),
    );
  }
}
