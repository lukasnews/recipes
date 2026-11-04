import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/household/presentation/allergies_screen.dart';
import '../features/household/presentation/household_setup_screen.dart';
import '../features/import/domain/recipe_draft.dart';
import '../features/ingredients/presentation/ingredient_edit_screen.dart';
import '../features/ingredients/presentation/ingredients_screen.dart';
import '../features/mealplan/presentation/meal_plan_screen.dart';
import '../features/pantry/presentation/pantry_screen.dart';
import '../features/recipes/presentation/cook_mode_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipe_edit_screen.dart';
import '../features/recipes/presentation/recipe_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shopping/presentation/shopping_list_screen.dart';
import 'home_shell.dart';
import 'providers.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

enum SessionState { loading, signedOut, needsHousehold, ready }

final sessionStateProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authUserProvider);
  if (auth.isLoading && !auth.hasValue) return SessionState.loading;
  if (auth.value == null) return SessionState.signedOut;
  final user = ref.watch(appUserProvider);
  if (user.isLoading && !user.hasValue) return SessionState.loading;
  return ref.watch(householdIdProvider) == null
      ? SessionState.needsHousehold
      : SessionState.ready;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(ref.read(sessionStateProvider));
  ref
    ..listen(sessionStateProvider, (_, next) => refresh.value = next)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.recipes,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final gate = switch (refresh.value) {
        SessionState.loading => Routes.splash,
        SessionState.signedOut => Routes.login,
        SessionState.needsHousehold => Routes.setup,
        SessionState.ready => null,
      };
      if (gate != null) return loc == gate ? null : gate;
      if (loc == Routes.splash || loc == Routes.login || loc == Routes.setup) {
        return Routes.recipes;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.setup,
        builder: (context, state) => const HouseholdSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.recipes,
                builder: (context, state) => const RecipeListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => RecipeEditScreen(
                      draft: state.extra is RecipeDraft
                          ? state.extra! as RecipeDraft
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RecipeDetailScreen(
                      recipeId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'cook',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => CookModeScreen(
                          recipeId: state.pathParameters['id']!,
                          servings: state.extra is int
                              ? state.extra! as int
                              : null,
                        ),
                      ),
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => RecipeEditScreen(
                          recipeId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.mealPlan,
                builder: (context, state) => const MealPlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.shopping,
                builder: (context, state) => const ShoppingListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pantry,
                builder: (context, state) => const PantryScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'household/add',
            builder: (context, state) =>
                const HouseholdSetupScreen(additional: true),
          ),
          GoRoute(
            path: 'allergies',
            builder: (context, state) => const AllergiesScreen(),
          ),
          GoRoute(
            path: 'ingredients',
            builder: (context, state) => const IngredientsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => IngredientEditScreen(
                  ingredientId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
