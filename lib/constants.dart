// ignore_for_file: constant_identifier_names

const validExtensions = ['.jpg', '.jpeg', '.png', '.bmp'];

enum Models {
  MLKIT,
  V1,
  V3,
  ONNX_MVIT_XX_S,
  ONNX_MVIT_X_S,
}

enum Architectures { TFLITE, ONNX, MLKIT }

class GalleryModelManager {
  static String getModelName(Models model) {
    switch (model) {
      case Models.MLKIT:
        return "ML Kit";
      case Models.V1:
        return "MobileNet V1";
      case Models.ONNX_MVIT_X_S:
        return "ONNX MobileViT X Small";
      case Models.ONNX_MVIT_XX_S:
        return "ONNX MobileViT XX Small";
      default:
        return "MobileNet V3";
    }
  }

  static Architectures getArchitecture(Models model) {
    switch (model) {
      case Models.ONNX_MVIT_XX_S || Models.ONNX_MVIT_X_S:
        return Architectures.ONNX;
      case Models.V1 || Models.V3:
        return Architectures.TFLITE;
      default:
        return Architectures.MLKIT;
    }
  }

  static String getMobileNetPath(bool isV3) {
    return isV3 ? modelPathV3 : modelPathV1;
  }

  static String getONNXMobileViTPath(Models model) {
    return model == Models.ONNX_MVIT_X_S
        ? modelPathONNXMobileViTXSmall
        : modelPathONNXMobileViTXXSmall;
  }

  static const String modelPathV1 = 'assets/models/mobilenet_quant.tflite';
  static const String modelPathV3 =
      'assets/models/mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tflite';
  static const String modelPathONNXMobileViTXXSmall =
      'assets/models/mobilevit-xx-small.onnx';
  static const String modelPathONNXMobileViTXSmall =
      'assets/models/mobilevit-x-small.onnx';
}

enum SearchTypes { fileName, category, semantic }

class SearchTypeManager {
  static String getSearchTypeName(SearchTypes searchType) {
    switch (searchType) {
      case SearchTypes.fileName:
        return "File name";
      case SearchTypes.semantic:
        return "Semantic";
      default:
        return "Category";
    }
  }
}

class SemanticModelManager {
  static const String jsonPath = "assets/models/mobileclip_b/tokenizer.json";
  static const String configPath =
      "assets/models/mobileclip_b/tokenizer_config.json";
  static const String txt2vecPath =
      "assets/models/mobileclip_b/text_model_quantized.onnx";
  static const String img2vecPath =
      "assets/models/mobileclip_b/vision_model_quantized.onnx";
}
