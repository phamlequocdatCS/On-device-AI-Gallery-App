# On-device-AI-Gallery-App

Gallery app with on-device AI-powered image search for Android and Windows.

See demonstration at [demo.md](demo.md)

Done at Ton Duc Thang University. Members:

- 521K0128 - Pham Le Quoc Dat
- 521K0143 - Duong Ngoc Bao Nhi
- 521K0110 - Le Thanh Loi

## Getting Started

Development environment: Windows 10
Tested on

- Emulated Android Pixel 7 Pro API 33
- Windows 10

Download models and place them in `assets/models/`:

- `mobilenet_quant`
  - <https://github.com/tensorflow/flutter-tflite/tree/main/example/image_classification_mobilenet/assets/models>
- `mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tflite`
  - Download `mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tar.gz`
  - From <https://www.kaggle.com/models/google/mobilenet-v3/tfLite/small-100-224-classification-metadata>
  - Unzip, rename `1.tflite` to `mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tflite`
- `mobilevit-xx-small`
  - <https://huggingface.co/Xenova/mobilevit-xx-small>
  - `git lfs install`
  - `git clone https://huggingface.co/Xenova/mobilevit-xx-small`
  - Rename `mobilevit-xx-small/onnx/model.onnx` to `mobilevit-xx-small.onnx`
- `mobilevit-x-small`
  - <https://huggingface.co/Xenova/mobilevit-x-small>
  - `git clone https://huggingface.co/Xenova/mobilevit-x-small`
  - Rename `mobilevit-x-small/onnx/model.onnx` to `mobilevit-x-small.onnx`
- `mobileclip_b`
  - <https://huggingface.co/Xenova/mobileclip_b>
  - `git clone https://huggingface.co/Xenova/mobileclip_b`
  - Copy `text_model_quantized.onnx, vision_model_quantized.onnx` to `models/mobileclip_b/`
  
The folder should look like this:

```txt
assets/models/
    labels.txt
    mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tflite
    mobilenet_quant.tflite
    mobilevit-xx-small.onnx
    mobilevit-x-small.onnx
    mobileclip_s0/
      text_model_quantized.onnx
      vision_model_quantized.onnx
      tokenizer.json
      tokenizer_config.json
```

To use TFLite, for Windows, the compiled file is included in this repository, but it may not work on your machine. If so, build Tensorflow by following these steps:

1. In ADMIN Powershell: `choco install bazelisk`
2. `git clone https://github.com/tensorflow/tensorflow.git tensorflow_src` (Place in directory whose path does not contain any spaces)
3. `bazel build -c opt //tensorflow/lite/c:tensorflowlite_c`
4. **Rename** and move `tensorflow_src/bazel-bin/tensorflow/lite/c/tensorflowlite_c.dll` to `windows/blobs/libtensorflowlite_c-win.dll`

Sources:

- <https://github.com/bazelbuild/bazelisk>
- <https://ai.google.dev/edge/litert/build/arm>
- <https://github.com/tensorflow/flutter-tflite/issues/185#issuecomment-1891846309>
- <https://bazel.build/install/windows>

Make sure to have NuGet

When modifying database.dart, please delete `database.g.dart` and run this:

```cmd
flutter clean
flutter pub get
dart run build_runner build
```

Building for Android

Building for Windows

```cmd
flutter clean
flutter pub get
flutter build windows --verbose
```

## Things to do

- [x] Compatibility
  - [x] Android
  - [x] Windows
- [x] Gallery View
  - [x] Thumbnails
  - [x] Full screen view
    - [x] Zoom while in full screen
  - [x] Customize grid size
  - [x] Auto grid size
- [x] Add Image(s)
  - [x] Windows
  - [x] Android
- [x] Loading screen
- [x] View image metadata
  - [x] Alert Dialog
  - [x] Size
  - [x] Resolution
  - [x] Filename
  - [x] Original filepath
  - [x] Filepath
  - [x] Date of creation
  - [x] Category
  - [x] Hash
  - [x] Model Name
- [x] AI Features
  - [x] Classification / Category / Tags
    - [x] Android (via ml_kit)
    - [x] Android (via flutter-tflite)
    - [x] Windows (via flutter-tflite)
      - [x] tensorflow dll
    - [x] Android (via ONNX Runtime)
    - [x] Windows (via ONNX Runtime)
  - [x] Semantic Search
    - [x] Android
    - [x] Windows
- [x] Search by metadata
  - [x] Search only by filename
  - [x] Search only by category
- [x] Permissions
  - [x] Camera
  - [x] Read photos

## Model hashes

| Model name | SHA256 |
|-|-|
|`mobilenet_quant.tflite`|`1a9abff0423b147a2de6d7cf8e31f309d5202ca3`|
|`mobilenet-v3-tflite-small-100-224-classification-metadata-v1.tflite`|`33816f797fd2d9c430b5fc9d9ba26122e765755c`|
|`mobileclip_b/text_model_quantized.onnx`|`0849d189da528f2b661e904b4ebe548a04645cbe37d7ff77bfc85928188bc9bd`|
|`mobileclip_b/vision_model_quantized.onnx`|`9c894e9699a16ea2557c3b71564f9d53dc1483dfded8e40b8dc63cf96d06117f`|
