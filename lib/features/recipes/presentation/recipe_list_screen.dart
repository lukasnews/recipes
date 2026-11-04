import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/matching/normalize.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/storage_image.dart';
import '../../import/presentation/import_actions.dart';
import '../../pantry/domain/pantry_item.dart';
import '../domain/allergen_check.dart';
import '../domain/cook_history.dart';
import '../domain/recipe.dart';
import '../domain/recipe_stock.dart';

/// Local full text search over title, tags and ingredient lines.
bool recipeMatches(Recipe r, String query) {
  final q = foldText(query);
  if (q.isEmpty) return true;
  final haystack = foldText(
    [
      r.title,
      ...r.tags,
      r.notes,
      for (final i in r.ingredients) i.rawText,
    ].join(' '),
  );
  return q.split(' ').every(haystack.contains);
}

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String? _category;
  bool _cookable = false;
  bool _safeForAll = false;
  bool _longNotCooked = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipesValue = ref.watch(recipesProvider);
    final ingredients = ref.watch(ingredientsByIdProvider);
    final pantry = ref.watch(pantryProvider).value ?? const {};
    final members = ref.watch(membersProvider).value ?? const [];
    bool isSafe(Recipe r) =>
        affectedMembers(recipeAllergens(r, ingredients), members).isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRecipes),
        actions: const [ProfileButton()],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipes-fab',
        tooltip: l10n.newRecipe,
        onPressed: () => showAddRecipeSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: AsyncView(
        value: recipesValue,
        data: (recipes) {
          final custom = {
            for (final r in recipes)
              if (!RecipeCategories.builtIn.contains(r.category)) r.category,
          }.toList()..sort();
          final filtered = recipes
              .where((r) => _category == null || r.category == _category)
              .where((r) => recipeMatches(r, _query))
              .where((r) => !_safeForAll || isSafe(r))
              .toList();
          var coverages = [
            for (final r in filtered) computeCoverage(r, ingredients, pantry),
          ];
          final expiring = expiringIds(pantry, DateTime.now());
          if (_cookable) {
            coverages = rankByCoverage(coverages, expiring: expiring);
          }
          if (_longNotCooked) {
            final stats = ref.watch(cookStatsProvider).value ?? const {};
            final byId = {for (final c in coverages) c.recipe.id: c};
            coverages = [
              for (final id in longNotCooked(byId.keys, stats)) byId[id]!,
            ];
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: SearchBar(
                  hintText: l10n.searchRecipesHint,
                  leading: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.kitchen_outlined),
                      label: Text(l10n.sortCookable),
                      selected: _cookable,
                      onSelected: (v) => setState(() {
                        _cookable = v;
                        if (v) _longNotCooked = false;
                      }),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.history),
                      label: Text(l10n.sortLongNotCooked),
                      selected: _longNotCooked,
                      onSelected: (v) => setState(() {
                        _longNotCooked = v;
                        if (v) _cookable = false;
                      }),
                    ),
                    if (members.any((m) => m.allergens.isNotEmpty))
                      FilterChip(
                        avatar: const Icon(Icons.health_and_safety_outlined),
                        label: Text(l10n.filterSafeForAll),
                        selected: _safeForAll,
                        onSelected: (v) => setState(() => _safeForAll = v),
                      ),
                    ChoiceChip(
                      label: Text(l10n.categoryAll),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in [...RecipeCategories.builtIn, ...custom])
                      ChoiceChip(
                        label: Text(l10n.category(c)),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: recipes.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book_outlined,
                        message:
                            '${l10n.recipesEmpty}\n${l10n.recipesEmptyHint}',
                      )
                    : coverages.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        message: l10n.noSearchResults,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: coverages.length,
                        itemBuilder: (context, i) => _RecipeTile(
                          coverage: coverages[i],
                          showCoverage: _cookable,
                          expiringUsed: coverages[i].usesExpiring(expiring),
                          warn: !isSafe(coverages[i].recipe),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.coverage,
    required this.showCoverage,
    this.warn = false,
    this.expiringUsed = 0,
  });

  /// Number of soon-expiring pantry items this recipe would use up.
  final int expiringUsed;

  final RecipeCoverage coverage;
  final bool showCoverage;

  /// Someone in the household can't eat this.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = coverage.recipe;
    final minutes = r.totalMinutes;
    final subtitle = [
      l10n.category(r.category),
      if (minutes != null) l10n.minutesShort(minutes),
      if (showCoverage && coverage.total > 0)
        l10n.coverageLabel(coverage.coveredCount, coverage.total),
      if (showCoverage && expiringUsed > 0) l10n.usesExpiring(expiringUsed),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        minVerticalPadding: 12,
        leading: r.photoPaths.isEmpty
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: StorageImage(
                    path: r.photoPaths.first,
                    thumbnailWidth: 56,
                  ),
                ),
              ),
        title: Text(r.title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warn)
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
            if (r.rating > 0) RatingStars(rating: r.rating, size: 16),
          ],
        ),
        onTap: () => context.push(Routes.recipe(r.id)),
      ),
    );
  }
}
