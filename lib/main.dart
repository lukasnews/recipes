import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/firebase/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await initFirebase();
  runApp(ProviderScope(child: RecipesApp(firebaseReady: firebaseReady)));
}
