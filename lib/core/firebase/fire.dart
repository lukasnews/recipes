import 'dart:async';

import 'package:flutter/foundation.dart';

/// Reports non-fatal errors. Replaced with Crashlytics in `main`.
void Function(Object error, StackTrace stack) reportError = (e, s) {
  debugPrint('Error: $e\n$s');
};

/// Starts a Firestore write without waiting for the server. Writes go to the
/// offline cache immediately; errors are reported, never block the UI.
void fire(Future<void> write) {
  unawaited(write.catchError((Object e, StackTrace s) => reportError(e, s)));
}
