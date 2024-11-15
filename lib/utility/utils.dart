import 'package:flutter/material.dart';

void showSnackBar(
    String message, GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) {
  scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
  var snackBar = SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 1),
  );
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}

bool matchesQuery(String searchField, String query) {
  return searchField.toLowerCase().contains(query.toLowerCase());
}
