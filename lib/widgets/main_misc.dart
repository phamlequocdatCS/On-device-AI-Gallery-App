import 'dart:io';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../database.dart';
import '../gallery_state.dart';
import '../utility/utils.dart';
import 'add_image_option.dart';
import 'more_widgets.dart';

List<PopupMenuEntry<SearchTypes>> getSearchTypeOptions(
  SearchTypes currentSearch,
) {
  return [
    getSearchTypeOption(currentSearch, SearchTypes.fileName),
    getSearchTypeOption(currentSearch, SearchTypes.category),
    getSearchTypeOption(currentSearch, SearchTypes.semantic),
  ];
}

List<PopupMenuEntry<int>> getColumnOptions(int columns) {
  return [
    getColumnOption(columns, 2, "2 Columns"),
    getColumnOption(columns, 3, "3 Columns"),
    getColumnOption(columns, 4, "4 Columns"),
    getColumnOption(columns, 5, "5 Columns"),
    getColumnOption(columns, -1, "Auto Columns"),
  ];
}

List<PopupMenuEntry<Models>> getModelOptions(Models currentModel) {
  return [
    getModelOption(currentModel, Models.V3),
    getModelOption(currentModel, Models.V1),
    getModelOption(currentModel, Models.ONNX_MVIT_XX_S),
    getModelOption(currentModel, Models.ONNX_MVIT_X_S),
    if (Platform.isAndroid) getModelOption(currentModel, Models.MLKIT),
  ];
}

IconButton getWipeButton(
  Color onPrimary,
  BuildContext context,
  GalleryState state,
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
) {
  return IconButton(
    icon: Icon(Icons.delete_forever, color: onPrimary),
    onPressed: () => forceWipeDatabase(
      context,
      state,
      scaffoldMessengerKey,
    ),
  );
}

PopupMenuButton<int> getColumnsMenu(Color onPrimary, GalleryState state) {
  return PopupMenuButton<int>(
    icon: Icon(Icons.view_module, color: onPrimary),
    onSelected: (int columns) => state.setColumns(columns),
    itemBuilder: (_) => getColumnOptions(state.columns),
  );
}

PopupMenuButton<Models> getModelsMenu(GalleryState state, Color onPrimary) {
  return PopupMenuButton<Models>(
    icon: Text(
      GalleryModelManager.getModelName(state.currentModel),
      style: TextStyle(color: onPrimary),
    ),
    onSelected: (Models model) => state.setModel(model),
    itemBuilder: (_) => getModelOptions(state.currentModel),
  );
}

void showAddImageOptions(
  BuildContext context,
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return AddImageOptions(
        scaffoldMessengerKey: scaffoldMessengerKey,
      );
    },
  );
}

void onThumbnailTapped(
  BuildContext context,
  ImageMetadata metadata,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FullScreenImage(
        metadata: metadata,
      ),
    ),
  );
}

void forceWipeDatabase(
  BuildContext context,
  GalleryState state,
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
) async {
  if (await showGenericConfirmationDialog(
    context,
    title: "Confirm Wiping",
    content: "Do you really want to wipe the database?",
  )) {
    if (context.mounted) {
      bool success = await state.forceWipeDatabase();
      if (success) {
        showSnackBar(
          'Database wiped successfully',
          scaffoldMessengerKey,
        );
      } else {
        showSnackBar('Failed to wipe database', scaffoldMessengerKey);
      }
    }
  }
}
