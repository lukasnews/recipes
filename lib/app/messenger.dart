import 'package:flutter/material.dart';

/// Lets background work (e.g. photo uploads) show a snack bar after the
/// screen that started it is gone.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showGlobalSnack(String message) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
