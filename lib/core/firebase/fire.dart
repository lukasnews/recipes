import 'dart:async';

import 'package:flutter/foundation.dart';

/// Reports non-fatal errors. Replaced with Crashlytics in `main`.
void Function(Object error, StackTrace stack) reportError = (e, s) {
  debugPrint('Error: $e\n$s');
};

/// Starts a Firestore write without waiting for the server. Writes go to the
/// offline cache immediately; errors are reported, never block the UI.
///
/// Callers often pass a `Future<DocumentReference>` or similar as
/// `Future<void>`; `catchError` would then demand a handler returning that
/// type and turn the write error into a crash. `then<void>` makes a new
/// `Future<void>`, so the handler may return nothing.
void fire(Future<void> write) {
  unawaited(
    write.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) => reportError(e, s),
    ),
  );
}
