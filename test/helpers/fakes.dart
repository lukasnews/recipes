import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipes/app/app.dart';
import 'package:recipes/app/providers.dart';
import 'package:recipes/core/firebase/photo_cache.dart';
import 'package:recipes/core/share/sharer.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/import/data/photo_picker.dart';
import 'package:recipes/features/import/data/recipe_extractor.dart';
import 'package:recipes/features/import/data/recipe_import_service.dart';
import 'package:recipes/features/import/data/shared_links.dart';
import 'package:recipes/features/import/data/text_recognizer.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/data/barcode_reader.dart';
import 'package:recipes/features/pantry/data/product_lookup.dart';
import 'package:recipes/features/pantry/domain/product.dart';
import 'package:recipes/features/recipes/data/photo_repository.dart';
import 'package:recipes/features/recipes/data/photo_upload_queue.dart';
import 'package:recipes/features/recipes/data/timer_alarms.dart';
import 'package:recipes/features/recipes/presentation/cook_timers.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._user]);

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  void _set(AuthUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signInWithEmail(String email, String password) async =>
      _set(AuthUser(uid: 'u-$email', email: email));

  @override
  Future<void> registerWithEmail(String name, String email, String pw) async =>
      _set(AuthUser(uid: 'u-$email', email: email, displayName: name));

  @override
  Future<void> signInWithGoogle() async =>
      _set(const AuthUser(uid: 'google', displayName: 'Google User'));

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _set(null);

  @override
  bool usesPassword = false;

  String? reauthPassword;
  var reauthenticated = false;
  var deleted = false;

  @override
  Future<void> reauthenticate({String? password}) async {
    reauthenticated = true;
    reauthPassword = password;
  }

  @override
  Future<void> deleteUser() async {
    deleted = true;
    _set(null);
  }
}

const testSeed = [
  Ingredient(id: 'mehl-glatt', name: 'Mehl glatt', synonyms: ['Mehl']),
  Ingredient(
    id: 'schlagobers',
    name: 'Schlagobers',
    synonyms: ['Sahne'],
    aisle: Aisle.dairy,
  ),
];

/// Signed-in user with a ready household; returns the household id.
Future<String> seedHousehold(FakeFirebaseFirestore db, {String uid = 'u1'}) {
  final repo = HouseholdRepository(db);
  return repo
      .ensureUser(uid, 'Lukas')
      .then(
        (_) => repo.createHousehold(uid: uid, name: 'Zuhause', seed: testSeed),
      )
      .then((hid) async {
        await db.collection('users').doc(uid).update({'onboardingDone': true});
        return hid;
      });
}

Widget testApp({
  required FakeFirebaseFirestore db,
  required FakeAuthRepository auth,
  RecipeImportService? importService,
  FakePhotoRepository? photos,
  FakeSharer? sharer,
  BarcodeReader? barcodes,
  ProductLookup? products,
  List<Ingredient>? seed,
  FakeExtractor? extractor,
}) => ProviderScope(
  overrides: [
    recipeExtractorProvider.overrideWith(
      (ref) async => extractor ?? FakeExtractor(const []),
    ),
    timerAlarmsProvider.overrideWithValue(const NoTimerAlarms()),
    barcodeReaderProvider.overrideWithValue(barcodes ?? FakeBarcodeReader()),
    productLookupProvider.overrideWithValue(products ?? FakeProductLookup()),
    sharerProvider.overrideWithValue(sharer ?? FakeSharer()),
    photoPickerProvider.overrideWithValue(FakePhotoPicker()),
    sharedLinkSourceProvider.overrideWithValue(FakeSharedLinks()),
    photoCacheProvider.overrideWithValue(FakePhotoCache()),
    photoRepositoryProvider.overrideWithValue(photos ?? FakePhotoRepository()),
    pendingUploadStoreProvider.overrideWithValue(MemoryPendingUploadStore()),
    photoUploaderProvider.overrideWithValue(
      (hid, rid, file) => (photos ?? FakePhotoRepository()).upload(rid, file),
    ),
    recipeImportServiceProvider.overrideWith(
      (ref) async => importService ?? fakeImportService(),
    ),
    firestoreProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(auth),
    seedIngredientsProvider.overrideWith((ref) async => seed ?? testSeed),
  ],
  child: const RecipesApp(),
);

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.paths = const ['/tmp/rezept.jpg']]);
  final List<String> paths;
  @override
  Future<List<String>> pick(PhotoSource source, {bool multiple = true}) async =>
      paths;
}

class FakeExtractor implements RecipeExtractor {
  FakeExtractor(this.results, {this.fail = false});
  final List<RecipeDraft> results;
  final bool fail;
  String? lastText;
  @override
  Future<List<RecipeDraft>> extract(List<Uint8List> jpegImages) async {
    if (fail) throw Exception('offline');
    return results;
  }

  @override
  Future<List<RecipeDraft>> extractFromText(String pageText) async {
    lastText = pageText;
    if (fail) throw Exception('offline');
    return results;
  }

  List<String>? lastPantry;
  String? lastWish;
  List<String>? lastAvoid;

  @override
  Future<List<RecipeDraft>> suggestFromPantry({
    required List<String> pantry,
    String wish = '',
    List<String> avoid = const [],
    int count = 3,
  }) async {
    lastPantry = pantry;
    lastWish = wish;
    lastAvoid = avoid;
    if (fail) throw Exception('offline');
    return results;
  }

  NutritionEstimate nutrition = const NutritionEstimate(
    kcal: 520,
    protein: 18,
    fat: 21,
    carbs: 62,
  );
  String? lastNutritionText;

  @override
  Future<NutritionEstimate> estimateNutrition(String recipeText) async {
    lastNutritionText = recipeText;
    if (fail) throw Exception('offline');
    return nutrition;
  }
}

class FakeOcr implements TextRecognizerService {
  FakeOcr(this.text);
  final String text;
  @override
  Future<String> recognize(String imagePath) async => text;
}

class FakePhotoRepository implements PhotoRepository {
  final uploaded = <String>[];
  @override
  Future<String> upload(String recipeId, String file) async {
    uploaded.add(file);
    return 'households/h/recipes/$recipeId/x.jpg';
  }

  @override
  Future<void> remove(String recipeId, String path) async {}
  @override
  Future<void> deleteFiles(Iterable<String> paths) async {}
  @override
  Future<String> downloadUrl(String path) async => 'https://example.invalid/x';
}

RecipeImportService fakeImportService({
  RecipeDraft? aiResult,
  List<RecipeDraft>? aiResults,
  String ocrText = '',
}) => RecipeImportService(
  extractor: FakeExtractor(
    aiResults ?? [?aiResult],
    fail: aiResult == null && aiResults == null,
  ),
  ocr: FakeOcr(ocrText),
  readBytes: (_) async => Uint8List(0),
);

class FakePhotoCache implements PhotoCache {
  final put_ = <String, String>{};
  @override
  Future<File?> cached(String path) async => null;
  @override
  Future<File> download(String path, String url) async => File('/nonexistent');
  @override
  Future<void> put(String path, String localFile) async =>
      put_[path] = localFile;
}

class FakeSharedLinks implements SharedLinkSource {
  // ignore: close_sinks
  final controller = StreamController<SharedItem>.broadcast();
  @override
  Stream<SharedItem> items() => controller.stream;
}

class FakeSharer implements Sharer {
  final texts = <String>[];
  final files = <String>[];

  @override
  Future<void> shareText(String text, {String? subject}) async =>
      texts.add(text);

  @override
  Future<void> shareFile(
    String path, {
    String? mimeType,
    String? subject,
  }) async => files.add(path);
}

class FakeBarcodeReader implements BarcodeReader {
  FakeBarcodeReader([this.code]);
  String? code;
  @override
  Future<String?> read(String imagePath) async => code;
}

class FakeProductLookup implements ProductLookup {
  FakeProductLookup([this.product]);
  Product? product;
  int calls = 0;
  @override
  Future<Product?> lookup(String code) async {
    calls++;
    final p = product;
    if (p == null) throw Exception('offline');
    return p;
  }
}

class MemoryPendingUploadStore implements PendingUploadStore {
  var items = <PendingUpload>[];
  @override
  Future<List<PendingUpload>> load() async => items;
  @override
  Future<void> save(List<PendingUpload> list) async => items = list;
  @override
  Future<String> keep(String file) async => file;
  @override
  Future<void> discard(String file) async {}
}
