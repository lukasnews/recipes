import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'fire.dart';

/// Initializes Firebase from the platform config (google-services.json).
/// Returns false when no config is bundled, e.g. in web previews.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured: $e');
    return false;
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  if (!kIsWeb) {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    reportError = crashlytics.recordError;
  }
  return true;
}
