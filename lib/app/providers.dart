import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/photo_cache.dart';
import '../core/matching/ingredient_matcher.dart';
import '../core/share/sharer.dart';
import '../core/units/display_units.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/household/data/member_repository.dart';
import '../features/household/domain/allergen.dart';
import '../features/household/domain/household.dart';
import '../features/import/data/link_importer.dart';
import '../features/import/data/photo_picker.dart';
import '../features/import/data/recipe_extractor.dart';
import '../features/import/data/recipe_import_service.dart';
import '../features/import/data/shared_links.dart';
import '../features/import/data/text_recognizer.dart';
import '../features/ingredients/data/ingredient_repository.dart';
import '../features/ingredients/domain/ingredient.dart';
import '../features/mealplan/data/meal_plan_repository.dart';
import '../features/pantry/data/frozen_meal_repository.dart';
import '../features/pantry/data/pantry_repository.dart';
import '../features/pantry/domain/frozen_meal.dart';
import '../features/pantry/domain/pantry_item.dart';
import '../features/recipes/data/photo_repository.dart';
import '../features/recipes/data/recipe_repository.dart';
import '../features/recipes/domain/cook_history.dart';
import '../features/recipes/domain/recipe.dart';
import '../features/settings/data/backup_service.dart';
import '../features/shopping/data/shopping_repository.dart';
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

final mealPlanProvider = StreamProvider<Map<String, List<String>>>(
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

final recipeImportServiceProvider = FutureProvider<RecipeImportService>(
  (ref) async => RecipeImportService(
    extractor: await ref.watch(recipeExtractorProvider.future),
    ocr: MlKitTextRecognizer(),
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

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(firestoreProvider), _requireHousehold(ref)),
);

final sharerProvider = Provider<Sharer>((ref) => const SystemSharer());

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
final unitDisplayProvider = Provider<UnitDisplay>(
  (ref) => UnitDisplay.parse(
    ref.watch(appUserProvider.select((u) => u.value?.unitDisplay)),
  ),
);

/// Recipe id -> how often / when last cooked.
final cookStatsProvider = StreamProvider<Map<String, CookStats>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchCookLog().map(cookStats),
);
