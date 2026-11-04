import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  await _activateAppCheck();
  // Fail fast offline; the photo queue retries on its own.
  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(minutes: 1));
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

/// Set for test builds from CI (GitHub secret APPCHECK_DEBUG_TOKEN). The same
/// token must be registered in Firebase -> App Check -> Apps -> Manage debug
/// tokens. Builds without it (Play releases) use Play Integrity.
const _appCheckDebugToken = String.fromEnvironment('APPCHECK_DEBUG_TOKEN');

/// App Check proves requests come from this app; Firebase AI Logic requires
/// it from November 2026.
Future<void> _activateAppCheck() async {
  if (kIsWeb) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: _appCheckDebugToken.isEmpty
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(debugToken: _appCheckDebugToken),
    );
  } catch (e, s) {
    reportError(e, s);
  }
}
