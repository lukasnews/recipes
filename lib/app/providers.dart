import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/fire.dart';
import '../core/firebase/photo_cache.dart';
import '../core/matching/ingredient_matcher.dart';
import '../core/share/sharer.dart';
import '../core/units/display_units.dart';
import '../core/widgets/url_opener.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/household/data/member_repository.dart';
import '../features/household/domain/allergen.dart';
import '../features/household/domain/household.dart';
import '../features/import/data/import_queue.dart';
import '../features/import/data/link_importer.dart';
import '../features/import/data/photo_picker.dart';
import '../features/import/data/recipe_extractor.dart';
import '../features/import/data/recipe_import_service.dart';
import '../features/import/data/shared_links.dart';
import '../features/import/data/text_recognizer.dart';
import '../features/ingredients/data/ingredient_repository.dart';
import '../features/ingredients/domain/ingredient.dart';
import '../features/mealplan/data/meal_plan_repository.dart';
import '../features/pantry/data/barcode_reader.dart';
import '../features/pantry/data/barcode_repository.dart';
import '../features/pantry/data/frozen_meal_repository.dart';
import '../features/pantry/data/pantry_repository.dart';
import '../features/pantry/data/product_lookup.dart';
import '../features/pantry/domain/frozen_meal.dart';
import '../features/pantry/domain/pantry_item.dart';
import '../features/recipes/data/photo_repository.dart';
import '../features/recipes/data/photo_upload_queue.dart';
import '../features/recipes/data/recipe_printer.dart';
import '../features/recipes/data/recipe_repository.dart';
import '../features/recipes/domain/cook_history.dart';
import '../features/recipes/domain/recipe.dart';
import '../features/recipes/domain/sample_recipes.dart';
import '../features/settings/data/account_deletion.dart';
import '../features/settings/data/backup_service.dart';
import '../features/sharing/data/shared_recipe_repository.dart';
import '../features/sharing/domain/shared_recipe.dart';
import '../features/shopping/data/home_screen_widget.dart';
import '../features/shopping/data/shopping_repository.dart';
import '../features/shopping/domain/aisle_order.dart';
import '../features/shopping/domain/shopping_item.dart';

// --- Firebase -------------------------------------------------------------

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

// --- Session --------------------------------------------------------------

final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(ref.watch(firestoreProvider)),
);

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authUserProvider.select((u) => u.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(householdRepositoryProvider).watchUser(uid);
});

/// Active household: the one picked in the settings, else the first.
final householdIdProvider = Provider<String?>(
  (ref) =>
      ref.watch(appUserProvider.select((u) => u.value?.currentHouseholdId)),
);

/// Any household the user belongs to (names for the switcher).
final householdByIdProvider = StreamProvider.family<Household?, String>(
  (ref, hid) => ref.watch(householdRepositoryProvider).watchHousehold(hid),
);

final householdProvider = StreamProvider<Household?>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return Stream.value(null);
  return ref.watch(householdRepositoryProvider).watchHousehold(hid);
});

String _requireHousehold(Ref ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) throw StateError('No household selected');
  return hid;
}

String _requireUid(Ref ref) {
  final uid = ref.watch(authUserProvider.select((u) => u.value?.uid));
  if (uid == null) throw StateError('Not signed in');
  return uid;
}

// --- Seed -----------------------------------------------------------------

/// Example recipes for new households, linked to the seed ingredients.
final sampleRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final seed = await ref.watch(seedIngredientsProvider.future);
  return sampleRecipes(
    await ref.watch(sampleRecipesRawProvider.future),
    IngredientMatcher(seed.map((i) => i.candidate)),
  );
});

final sampleRecipesRawProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/seed/recipes_de.json');
  return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
});

final seedIngredientsProvider = FutureProvider<List<Ingredient>>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/ingredients_de.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return [
    for (final m in list.cast<Map<String, dynamic>>())
      Ingredient.fromMap(m['id'] as String, m),
  ];
});

// --- Repositories ---------------------------------------------------------

final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => IngredientRepository(
    ref.watch(firestoreProvider),
    _requireHousehold(ref),
  ),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) =>
      RecipeRepository(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final pantryRepositoryProvider = Provider<PantryRepository>(
  (ref) =>
      PantryRepository(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(
    ref.watch(firestoreProvider),
    _requireHousehold(ref),
    _requireUid(ref),
  ),
);

final mealPlanRepositoryProvider = Provider<MealPlanRepository>(
  (ref) =>
      MealPlanRepository(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

// --- Live data ------------------------------------------------------------

final ingredientsProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(ingredientRepositoryProvider).watchAll(),
);

final ingredientsByIdProvider = Provider<Map<String, Ingredient>>((ref) {
  final list = ref.watch(ingredientsProvider).value ?? const [];
  return {for (final i in list) i.id: i};
});

final ingredientMatcherProvider = Provider<IngredientMatcher>((ref) {
  final list = ref.watch(ingredientsProvider).value ?? const [];
  return IngredientMatcher(list.map((i) => i.candidate));
});

final recipesProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchAll(),
);

final pantryProvider = StreamProvider<Map<String, PantryItem>>(
  (ref) => ref.watch(pantryRepositoryProvider).watchAll(),
);

final shoppingProvider = StreamProvider<List<ShoppingItem>>(
  (ref) => ref.watch(shoppingRepositoryProvider).watchAll(),
);

final mealPlanProvider = StreamProvider<Map<String, MealPlanDay>>(
  (ref) => ref.watch(mealPlanRepositoryProvider).watchAll(),
);

// --- Import & photos ------------------------------------------------------

/// Gemini model name from Remote Config key `ai_model` (never hard coded
/// in a release; the value here is only the fallback default).
final aiModelProvider = FutureProvider<String>((ref) async {
  const fallback = 'gemini-3.8-flash';
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults(const {'ai_model': fallback});
    await rc.fetchAndActivate().timeout(const Duration(seconds: 5));
    final v = rc.getString('ai_model').trim();
    return v.isEmpty ? fallback : v;
  } catch (_) {
    return fallback;
  }
});

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);

final recipeExtractorProvider = FutureProvider<RecipeExtractor>(
  (ref) async => GeminiRecipeExtractor(await ref.watch(aiModelProvider.future)),
);

final linkImporterProvider = FutureProvider<LinkImporter>(
  (ref) async =>
      LinkImporter(extractor: await ref.watch(recipeExtractorProvider.future)),
);

final importQueueStoreProvider = Provider<ImportQueueStore>(
  (ref) => FileImportQueueStore(),
);

/// Recipe photos taken offline, read by the AI once online.
final importQueueProvider = NotifierProvider<ImportQueue, List<PendingImport>>(
  () => ImportQueue(
    store: (ref) => ref.read(importQueueStoreProvider),
    reader: (ref, paths) async =>
        (await ref.read(recipeImportServiceProvider.future))
            .importWhenOnline(paths),
  ),
);

final recipeImportServiceProvider = FutureProvider<RecipeImportService>(
  (ref) async => RecipeImportService(
    extractor: await ref.watch(recipeExtractorProvider.future),
    ocr: MlKitTextRecognizer(),
  ),
);

final pendingUploadStoreProvider = Provider<PendingUploadStore>(
  (ref) => FilePendingUploadStore(),
);

/// Uploads one photo for any household (queued items may belong to a
/// household other than the active one).
final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) =>
      (hid, rid, file) => FirebasePhotoRepository(
        FirebaseStorage.instance,
        ref.read(firestoreProvider),
        hid,
      ).upload(rid, file),
);

/// Recipe photos waiting for their upload (kept across restarts).
final photoUploadQueueProvider =
    NotifierProvider<PhotoUploadQueue, List<PendingUpload>>(
      () => PhotoUploadQueue(
        store: (ref) => ref.read(pendingUploadStoreProvider),
        uploader: (ref) => ref.read(photoUploaderProvider),
        // Keep the local file so this phone never downloads it again.
        onUploaded: (ref, path, file) => ref
            .read(photoCacheProvider)
            .put(path, file)
            .catchError(reportError),
      ),
    );

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => FirebasePhotoRepository(
    FirebaseStorage.instance,
    ref.watch(firestoreProvider),
    _requireHousehold(ref),
  ),
);

final photoCacheProvider = Provider<PhotoCache>(
  (ref) => CacheManagerPhotoCache(),
);

/// Local file for a photo: from the disk cache, downloaded only once.
final photoFileProvider = FutureProvider.family<File, String>((
  ref,
  path,
) async {
  final cache = ref.watch(photoCacheProvider);
  final hit = await cache.cached(path);
  if (hit != null) return hit;
  final url = await ref.read(photoRepositoryProvider).downloadUrl(path);
  return cache.download(path, url);
});

final accountDeletionProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(
    ref.watch(firestoreProvider),
    // Read lazily: without a household there are no photos to delete.
    (paths) => ref.read(photoRepositoryProvider).deleteFiles(paths),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final barcodeReaderProvider = Provider<BarcodeReader>(
  (ref) => MlKitBarcodeReader(),
);

final productLookupProvider = Provider<ProductLookup>(
  (ref) => OpenFoodFactsLookup(),
);

final barcodeRepositoryProvider = Provider<BarcodeRepository>(
  (ref) =>
      BarcodeRepository(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final homeScreenWidgetProvider = Provider<HomeScreenWidget>(
  (ref) => platformHomeScreenWidget(),
);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => const BrowserUrlOpener(),
);

final sharerProvider = Provider<Sharer>((ref) => const SystemSharer());

final recipePrinterProvider = Provider<RecipePrinter>(
  (ref) => const SystemRecipePrinter(),
);

final sharedLinkSourceProvider = Provider<SharedLinkSource>(
  (ref) => ReceiveSharingIntentLinks(),
);

// --- Members & allergies --------------------------------------------------

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) =>
      MemberRepository(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final membersProvider = StreamProvider<List<HouseholdMember>>(
  (ref) => ref.watch(memberRepositoryProvider).watchAll(),
);

// --- Frozen meals ---------------------------------------------------------

final frozenMealRepositoryProvider = Provider<FrozenMealRepository>(
  (ref) => FrozenMealRepository(
    ref.watch(firestoreProvider),
    _requireHousehold(ref),
  ),
);

final frozenMealsProvider = StreamProvider<List<FrozenMeal>>(
  (ref) => ref.watch(frozenMealRepositoryProvider).watchAll(),
);

/// How amounts are shown (per person, stored on users/{uid}).
/// This person's favourite recipe ids.
final sharedRecipeRepositoryProvider = Provider<SharedRecipeRepository>(
  (ref) => SharedRecipeRepository(ref.watch(firestoreProvider)),
);

/// Recipes this person sent to other households.
final sentRecipesProvider = StreamProvider<List<SharedRecipe>>((ref) {
  final uid = ref.watch(authUserProvider.select((u) => u.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(sharedRecipeRepositoryProvider).watchSentBy(uid);
});

final favoritesProvider = Provider<Set<String>>(
  (ref) =>
      ref.watch(appUserProvider.select((u) => u.value?.favoriteRecipeIds)) ??
      const {},
);

/// All collection names used in the household, sorted.
final collectionsProvider = Provider<List<String>>((ref) {
  final names = <String>{
    for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
      ...r.collections,
  };
  return names.toList()..sort();
});

/// Shopping list sections in this person's order.
/// The household's shops (Hofer, Billa, …) in its order.
final storesProvider = Provider<List<String>>(
  (ref) =>
      ref.watch(householdProvider.select((h) => h.value?.stores)) ??
      Household.defaultStores,
);

/// Own flyer links per shop.
final storeLinksProvider = Provider<Map<String, String>>(
  (ref) =>
      ref.watch(householdProvider.select((h) => h.value?.storeLinks)) ??
      const {},
);

/// Shopping list grouped by shop instead of aisle (per person).
final shoppingByStoreProvider = Provider<bool>(
  (ref) =>
      ref.watch(appUserProvider.select((u) => u.value?.shoppingByStore)) ??
      false,
);

final aisleOrderProvider = Provider<List<Aisle>>(
  (ref) =>
      aisleOrder(ref.watch(appUserProvider.select((u) => u.value?.aisleOrder))),
);

final unitDisplayProvider = Provider<UnitDisplay>(
  (ref) => UnitDisplay.parse(
    ref.watch(appUserProvider.select((u) => u.value?.unitDisplay)),
  ),
);

/// Recipe id -> how often / when last cooked.
final cookStatsProvider = StreamProvider<Map<String, CookStats>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchCookLog().map(cookStats),
);
