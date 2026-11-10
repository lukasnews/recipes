import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
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
import '../domain/recipe_variants.dart';
import '../domain/sample_recipes.dart';

/// Local full text search over title, tags and ingredient lines.
bool recipeMatches(Recipe r, String query) {
  final q = foldText(query);
  if (q.isEmpty) return true;
  final haystack = foldText(
    [
      r.title,
      ?r.variantName,
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
  bool _showFilters = false;
  bool _favoritesOnly = false;
  String? _collection;
  String? _tag;
  String _query = '';

  /// Example recipes for a household that has none (yet).
  Future<void> _addSamples() async {
    final raw = await ref.read(sampleRecipesRawProvider.future);
    final recipes = sampleRecipes(raw, ref.read(ingredientMatcherProvider));
    final repo = ref.read(recipeRepositoryProvider);
    for (final r in recipes) {
      fire(repo.save(r, isNew: true));
    }
  }

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
        actions: [
          IconButton(
            tooltip: l10n.menusTitle,
            onPressed: () => context.push(Routes.menus),
            icon: const Icon(Icons.restaurant_menu),
          ),
          const ProfileButton(),
        ],
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
          final favorites = ref.watch(favoritesProvider);
          final collections = ref.watch(collectionsProvider);
          if (_collection != null && !collections.contains(_collection)) {
            _collection = null;
          }
          final tags = ref.watch(tagsProvider).take(12).toList();
          if (_tag != null && !tags.contains(_tag)) _tag = null;
          final filtered = recipes
              .where((r) => _category == null || r.category == _category)
              .where((r) => recipeMatches(r, _query))
              .where((r) => !_safeForAll || isSafe(r))
              .where((r) => !_favoritesOnly || favorites.contains(r.id))
              .where(
                (r) =>
                    _collection == null || r.collections.contains(_collection),
              )
              .where((r) => _tag == null || r.tags.contains(_tag))
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

          // One tile per recipe family, unless only a variant matches.
          coverages = collapseVariants(coverages, (c) => c.recipe);
          final variants = variantCounts(recipes);

          final showSafeFilter = members.any((m) => m.allergens.isNotEmpty);
          final activeFilters = [
            _cookable,
            _longNotCooked,
            _safeForAll && showSafeFilter,
            _favoritesOnly,
            _collection != null,
            _tag != null,
          ].where((b) => b).length;

          return Column(
            children: [
              const _ImportQueueBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: SearchBar(
                  hintText: l10n.searchRecipesHint,
                  leading: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.categoryAll),
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final c in [
                            ...RecipeCategories.builtIn,
                            ...custom,
                          ])
                            ChoiceChip(
                              label: Text(l10n.category(c)),
                              selected: _category == c,
                              onSelected: (_) => setState(() => _category = c),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Badge(
                      isLabelVisible: activeFilters > 0 && !_showFilters,
                      label: Text('$activeFilters'),
                      child: IconButton(
                        tooltip: l10n.moreFilters,
                        isSelected: _showFilters,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                        icon: const Icon(Icons.tune),
                        selectedIcon: const Icon(Icons.expand_less),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: !_showFilters
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              avatar: const Icon(Icons.favorite_border),
                              label: Text(l10n.filterFavorites),
                              selected: _favoritesOnly,
                              onSelected: (v) =>
                                  setState(() => _favoritesOnly = v),
                            ),
                            for (final t in tags)
                              FilterChip(
                                label: Text('#$t'),
                                selected: _tag == t,
                                onSelected: (v) =>
                                    setState(() => _tag = v ? t : null),
                              ),
                            for (final c in collections)
                              FilterChip(
                                avatar: const Icon(
                                  Icons.collections_bookmark_outlined,
                                ),
                                label: Text(c),
                                selected: _collection == c,
                                onSelected: (v) =>
                                    setState(() => _collection = v ? c : null),
                              ),
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
                            if (showSafeFilter)
                              FilterChip(
                                avatar: const Icon(
                                  Icons.health_and_safety_outlined,
                                ),
                                label: Text(l10n.filterSafeForAll),
                                selected: _safeForAll,
                                onSelected: (v) =>
                                    setState(() => _safeForAll = v),
                              ),
                          ],
                        ),
                      ),
              ),
              Expanded(
                child: recipes.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book_outlined,
                        message:
                            '${l10n.recipesEmpty}\n${l10n.recipesEmptyHint}',
                        action: OutlinedButton.icon(
                          onPressed: _addSamples,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(l10n.addSampleRecipes),
                        ),
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
                          favorite: favorites.contains(coverages[i].recipe.id),
                          warn: !isSafe(coverages[i].recipe),
                          variants: variants[coverages[i].recipe.id] ?? 0,
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
    this.favorite = false,
    this.variants = 0,
  });

  final bool favorite;

  /// Number of variants of this original.
  final int variants;

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
      if (variants > 0) l10n.variantCount(variants),
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
            if (favorite)
              Icon(
                Icons.favorite,
                size: 18,
                color: Colors.redAccent,
                semanticLabel: context.l10n.filterFavorites,
              ),
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

/// Photos queued for the AI: "wartet auf Internet" or "gelesen – prüfen".
class _ImportQueueBanner extends ConsumerWidget {
  const _ImportQueueBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queue = ref.watch(importQueueProvider);
    final ready = queue.where((i) => i.isReady).length;
    final waiting = queue.length - ready;
    if (queue.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      color: ready > 0
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(ready > 0 ? Icons.auto_awesome : Icons.cloud_off),
        title: Text(
          ready > 0
              ? l10n.importQueueReady(ready)
              : l10n.importQueueWaiting(waiting),
        ),
        subtitle: ready > 0 && waiting > 0
            ? Text(l10n.importQueueWaiting(waiting))
            : null,
        trailing: ready > 0
            ? FilledButton(
                onPressed: () => reviewQueuedImports(context, ref),
                child: Text(l10n.importQueueReview),
              )
            : null,
      ),
    );
  }
}
