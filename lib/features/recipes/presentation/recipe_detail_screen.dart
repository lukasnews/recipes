import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/display_units.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/storage_image.dart';
import '../../mealplan/domain/meal_plan_day.dart';
import '../domain/allergen_check.dart';
import '../domain/cook_history.dart';
import '../domain/nutrition.dart';
import '../domain/recipe.dart';
import '../domain/recipe_share.dart';
import '../domain/recipe_stock.dart';
import 'cooked_dialog.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings;

  Future<void> _delete(Recipe recipe) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.confirmDeleteRecipe(recipe.title),
      confirmLabel: l10n.delete,
    );
    if (!ok || !mounted) return;
    fire(ref.read(recipeRepositoryProvider).delete(recipe.id));
    if (recipe.photoPaths.isNotEmpty) {
      fire(ref.read(photoRepositoryProvider).deleteFiles(recipe.photoPaths));
    }
    context.pop();
    showSnack(context, l10n.recipeDeleted);
  }

  void _share(Recipe recipe, int servings) {
    final l10n = context.l10n;
    final text = recipeShareText(
      recipe,
      labels: (
        servings: l10n.servingsCount,
        ingredients: l10n.ingredientsTitle,
        steps: l10n.stepsTitle,
      ),
      ingredients: ref.read(ingredientsByIdProvider),
      display: ref.read(unitDisplayProvider),
      servings: servings,
    );
    fire(ref.read(sharerProvider).shareText(text, subject: recipe.title));
  }

  Future<void> _planDay(Recipe recipe) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    fire(ref.read(mealPlanRepositoryProvider).add(dayKey(day), recipe.id));
    showSnack(
      context,
      l10n.addedToMealPlan(DateFormat('EEEE, d. MMMM', 'de').format(day)),
    );
  }

  Future<void> _buyMissing(RecipeCoverage coverage) async {
    final l10n = context.l10n;
    final repo = ref.read(shoppingRepositoryProvider);
    final current = ref.read(shoppingProvider).value ?? const [];
    final missing = coverage.missing;
    if (alreadyOnList(coverage.recipe.id, missing, current)) {
      final again = await confirmDialog(
        context,
        title: l10n.buyMissingAgainTitle,
        message: l10n.buyMissingAgainMessage,
        confirmLabel: l10n.buyMissingAgain,
      );
      if (!again || !mounted) return;
    }
    for (final need in missing) {
      final ing = need.ingredient;
      final knowAmount = need.neededBase > 0 && !need.hasUnconvertible;
      fire(
        repo.add(
          text: ing.name,
          current: current,
          ingredientId: ing.id,
          amount: knowAmount ? need.missingBase : null,
          unit: knowAmount
              ? (ing.baseUnit == BaseUnit.pcs ? 'Stk.' : ing.baseUnit.name)
              : null,
          aisle: ing.aisle,
          fromRecipeId: coverage.recipe.id,
        ),
      );
    }
    showSnack(context, l10n.buyMissingDone(missing.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider).value;
    final recipe = recipes?.where((r) => r.id == widget.recipeId).firstOrNull;
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: recipes == null
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off, message: l10n.noSearchResults),
      );
    }
    final ingredients = ref.watch(ingredientsByIdProvider);
    final pantry = ref.watch(pantryProvider).value ?? const {};
    final servings = _servings ?? recipe.servings;
    final coverage = computeCoverage(
      recipe,
      ingredients,
      pantry,
      servings: servings,
    );
    final needs = {for (final n in coverage.needs) n.ingredient.id: n};
    final allergens = recipeAllergens(recipe, ingredients);
    final stats = ref.watch(cookStatsProvider).value?[recipe.id];
    final pendingPhotos = [
      for (final p in ref.watch(photoUploadQueueProvider))
        if (p.recipeId == recipe.id) p,
    ];
    final frozen = (ref.watch(frozenMealsProvider).value ?? const [])
        .where((m) => m.recipeId == recipe.id)
        .fold<int>(0, (sum, m) => sum + m.portions);
    final affected = affectedMembers(
      allergens,
      ref.watch(membersProvider).value ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: l10n.addToMealPlan,
            onPressed: () => _planDay(recipe),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: l10n.shareRecipe,
            onPressed: () => _share(recipe, servings),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: l10n.edit,
            onPressed: () => context.push(Routes.editRecipe(recipe.id)),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _delete(recipe),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (recipe.photoPaths.isNotEmpty || pendingPhotos.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: PageView(
                  children: [
                    for (final p in recipe.photoPaths) StorageImage(path: p),
                    // Not uploaded yet (offline): shown from the phone.
                    for (final p in pendingPhotos)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(p.file), fit: BoxFit.cover),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Chip(
                              avatar: const Icon(Icons.cloud_upload_outlined),
                              label: Text(l10n.photoPendingUpload),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text(l10n.category(recipe.category))),
              if (recipe.prepMinutes != null)
                Chip(
                  avatar: const Icon(Icons.timer_outlined),
                  label: Text(
                    '${l10n.prepTime} ${l10n.minutesShort(recipe.prepMinutes!)}',
                  ),
                ),
              if (recipe.cookMinutes != null)
                Chip(
                  avatar: const Icon(Icons.local_fire_department_outlined),
                  label: Text(
                    '${l10n.cookTime} ${l10n.minutesShort(recipe.cookMinutes!)}',
                  ),
                ),
              for (final t in recipe.tags) Chip(label: Text('#$t')),
              if (frozen > 0)
                Chip(
                  avatar: const Icon(Icons.ac_unit),
                  label: Text(l10n.inFreezer(frozen)),
                ),
            ],
          ),
          if (allergens.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: affected.isEmpty
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  affected.isEmpty
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded,
                ),
                title: Text(l10n.allergenWarning(l10n.allergenList(allergens))),
                subtitle: affected.isEmpty
                    ? null
                    : Text(
                        l10n.allergenAffects(
                          [
                            for (final (m, a) in affected)
                              '${m.displayName} (${l10n.allergenList(a)})',
                          ].join(', '),
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            stats == null
                ? l10n.neverCooked
                : '${l10n.lastCooked(daysBetween(stats.lastCooked, DateTime.now()))}'
                      ' · ${l10n.cookedTimes(stats.count)}',
            style: theme.textTheme.bodySmall,
          ),
          _NutritionRow(recipe: recipe),
          const SizedBox(height: 8),
          RatingStars(
            rating: recipe.rating,
            onChanged: (v) => fire(
              ref.read(recipeRepositoryProvider).setRating(recipe.id, v),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l10n.servingsLabel, style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: servings > 1
                    ? () => setState(() => _servings = servings - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$servings', style: theme.textTheme.titleLarge),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _servings = servings + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.ingredientsTitle, style: theme.textTheme.titleLarge),
          for (final line in recipe.ingredients)
            _IngredientRow(
              line: line,
              scaledAmount: line.amount == null
                  ? null
                  : scaleAmount(line.amount!, recipe.servings, servings),
              need: needs[line.ingredientId],
              display: ref.watch(unitDisplayProvider),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _buyMissing(coverage),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(l10n.buyMissing),
              ),
              if (recipe.steps.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final cooked = await context.push<bool>(
                      Routes.cookRecipe(recipe.id),
                      extra: servings,
                    );
                    if (cooked == true && context.mounted) {
                      await showCookedDialog(context, ref, recipe, servings);
                    }
                  },
                  icon: const Icon(Icons.soup_kitchen_outlined),
                  label: Text(l10n.cookMode),
                ),
              FilledButton.icon(
                onPressed: () =>
                    showCookedDialog(context, ref, recipe, servings),
                icon: const Icon(Icons.restaurant),
                label: Text(l10n.cooked),
              ),
            ],
          ),
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l10n.stepsTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (i, step) in recipe.steps.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, child: Text('${i + 1}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(step.text, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
          ],
          if (recipe.sourceUrl != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              l10n.sourceLabel(
                Uri.tryParse(recipe.sourceUrl!)?.host ?? recipe.sourceUrl!,
              ),
              style: theme.textTheme.bodySmall,
            ),
            SelectableText(recipe.sourceUrl!, style: theme.textTheme.bodySmall),
          ],
          if (recipe.notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l10n.notesTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(recipe.notes),
          ],
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.line,
    required this.scaledAmount,
    required this.need,
    required this.display,
  });

  final UnitDisplay display;

  final RecipeIngredient line;
  final double? scaledAmount;
  final IngredientNeed? need;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final name = need?.ingredient.name ?? line.name ?? line.rawText;
    final qty = displayQuantity(scaledAmount, line.unit, display);
    final (IconData icon, Color color, String? hint) = switch (need?.status) {
      StockStatus.available => (
        Icons.check_circle,
        Colors.green,
        l10n.stockAvailable,
      ),
      StockStatus.partial => (
        Icons.timelapse,
        Colors.orange,
        l10n.stockPartial(
          formatBaseAmount(need!.haveBase, need!.ingredient.baseUnit),
        ),
      ),
      StockStatus.missing => (
        Icons.cancel_outlined,
        scheme.error,
        l10n.stockMissing,
      ),
      _ => (Icons.remove, scheme.outline, null),
    };
    final id = need?.ingredient.id;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: id == null ? null : () => context.push(Routes.ingredient(id)),
      leading: Icon(icon, color: color),
      title: Text([if (qty.isNotEmpty) qty, name].join(' ')),
      subtitle: Text([?line.note, ?hint].join(' · ')),
    );
  }
}

/// AI estimate per serving; a button to (re)estimate it.
class _NutritionRow extends ConsumerStatefulWidget {
  const _NutritionRow({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_NutritionRow> createState() => _NutritionRowState();
}

class _NutritionRowState extends ConsumerState<_NutritionRow> {
  var _busy = false;

  Future<void> _estimate() async {
    final l10n = context.l10n;
    final r = widget.recipe;
    setState(() => _busy = true);
    try {
      final extractor = await ref.read(recipeExtractorProvider.future);
      final n = await extractor.estimateNutrition(
        nutritionPrompt(
          title: r.title,
          servings: r.servings,
          ingredientLines: [for (final l in r.ingredients) l.rawText],
        ),
      );
      fire(ref.read(recipeRepositoryProvider).setNutrition(r.id, n));
    } catch (e, st) {
      reportError(e, st);
      if (mounted) showSnack(context, l10n.nutritionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final n = widget.recipe.nutrition;
    if (widget.recipe.ingredients.isEmpty) return const SizedBox.shrink();
    if (n == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : _estimate,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.local_fire_department_outlined),
          label: Text(l10n.nutritionEstimate),
        ),
      );
    }
    String g(double v) => v.round().toString();
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.nutritionPerServing(
              n.kcal,
              g(n.protein),
              g(n.fat),
              g(n.carbs),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: l10n.nutritionRefresh,
          onPressed: _busy ? null : _estimate,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }
}
