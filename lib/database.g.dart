// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageMetadataAdapter extends TypeAdapter<ImageMetadata> {
  @override
  final int typeId = 0;

  @override
  ImageMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageMetadata(
      filename: fields[0] as String,
      fileSize: fields[1] as String,
      fileResolution: fields[2] as String,
      categories: (fields[3] as List).cast<String>(),
      timeOfCreation: fields[4] as DateTime,
      filePath: fields[5] as String,
      originalFilePath: fields[6] as String,
      hash: fields[7] as String,
      modelName: fields[8] as String?,
      imageEmbedding: (fields[9] as List?)?.cast<double>(),
      thumbnailPath: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageMetadata obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.filename)
      ..writeByte(1)
      ..write(obj.fileSize)
      ..writeByte(2)
      ..write(obj.fileResolution)
      ..writeByte(3)
      ..write(obj.categories)
      ..writeByte(4)
      ..write(obj.timeOfCreation)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.originalFilePath)
      ..writeByte(7)
      ..write(obj.hash)
      ..writeByte(8)
      ..write(obj.modelName)
      ..writeByte(9)
      ..write(obj.imageEmbedding)
      ..writeByte(10)
      ..write(obj.thumbnailPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
