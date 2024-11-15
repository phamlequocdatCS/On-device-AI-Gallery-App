import 'package:hive_flutter/hive_flutter.dart';
part 'database.g.dart';

@HiveType(typeId: 0)
class ImageMetadata extends HiveObject {
  @HiveField(0)
  final String filename;

  @HiveField(1)
  final String fileSize;

  @HiveField(2)
  final String fileResolution;

  @HiveField(3)
  final List<String> categories;

  @HiveField(4)
  final DateTime timeOfCreation;

  @HiveField(5)
  final String filePath;

  @HiveField(6)
  final String originalFilePath;

  @HiveField(7)
  final String hash;

  @HiveField(8)
  final String? modelName;

  @HiveField(9)
  final List<double>? imageEmbedding;

  @HiveField(10)
  String? thumbnailPath;

  ImageMetadata({
    required this.filename,
    required this.fileSize,
    required this.fileResolution,
    required this.categories,
    required this.timeOfCreation,
    required this.filePath,
    required this.originalFilePath,
    required this.hash,
    this.modelName,
    this.imageEmbedding,
    this.thumbnailPath,
  });

  ImageMetadata copyWith({
    String? filename,
    String? fileSize,
    String? fileResolution,
    List<String>? categories,
    DateTime? timeOfCreation,
    String? filePath,
    String? originalFilePath,
    String? hash,
    String? modelName,
    List<double>? imageEmbedding,
    String? thumbnailPath,
  }) {
    return ImageMetadata(
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      fileResolution: fileResolution ?? this.fileResolution,
      categories: categories ?? this.categories,
      timeOfCreation: timeOfCreation ?? this.timeOfCreation,
      filePath: filePath ?? this.filePath,
      originalFilePath: originalFilePath ?? this.originalFilePath,
      hash: hash ?? this.hash,
      modelName: modelName ?? this.modelName,
      imageEmbedding: imageEmbedding ?? this.imageEmbedding,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
