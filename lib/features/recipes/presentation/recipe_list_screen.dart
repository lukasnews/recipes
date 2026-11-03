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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipesValue = ref.watch(recipesProvider);
    final ingredients = ref.watch(ingredientsByIdProvider);
    final pantry = ref.watch(pantryProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRecipes),
        actions: const [ProfileButton()],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipes-fab',
        tooltip: l10n.newRecipe,
        onPressed: () => context.push(Routes.newRecipe),
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
              .toList();
          var coverages = [
            for (final r in filtered) computeCoverage(r, ingredients, pantry),
          ];
          if (_cookable) coverages = rankByCoverage(coverages);

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
                      onSelected: (v) => setState(() => _cookable = v),
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
  const _RecipeTile({required this.coverage, required this.showCoverage});

  final RecipeCoverage coverage;
  final bool showCoverage;

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
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(r.title),
        subtitle: Text(subtitle),
        trailing: r.rating > 0 ? RatingStars(rating: r.rating, size: 16) : null,
        onTap: () => context.push(Routes.recipe(r.id)),
      ),
    );
  }
}
