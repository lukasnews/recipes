import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/matching/ingredient_matcher.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/household/domain/household.dart';
import '../features/ingredients/data/ingredient_repository.dart';
import '../features/ingredients/domain/ingredient.dart';
import '../features/mealplan/data/meal_plan_repository.dart';
import '../features/pantry/data/pantry_repository.dart';
import '../features/pantry/domain/pantry_item.dart';
import '../features/recipes/data/recipe_repository.dart';
import '../features/recipes/domain/recipe.dart';
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

/// Active household; the first one the user belongs to.
final householdIdProvider = Provider<String?>((ref) {
  final ids = ref.watch(appUserProvider.select((u) => u.value?.householdIds));
  return (ids == null || ids.isEmpty) ? null : ids.first;
});

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
