import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/mealplan/presentation/meal_plan_screen.dart';
import '../features/pantry/presentation/pantry_screen.dart';
import '../features/recipes/presentation/recipe_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shopping/presentation/shopping_list_screen.dart';
import 'home_shell.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.recipes,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.recipes,
                builder: (context, state) => const RecipeListScreen(),
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
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
