import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../sharing/presentation/share_actions.dart';
import '../domain/allergen_check.dart';
import '../domain/baking_pan.dart';
import '../domain/cook_history.dart';
import '../domain/nutrition.dart';
import '../domain/recipe.dart';
import '../domain/recipe_pdf.dart';
import '../domain/recipe_share.dart';
import '../domain/recipe_stock.dart';
import '../domain/recipe_variants.dart';
import 'collections_sheet.dart';
import 'cooked_dialog.dart';
import 'pan_fields.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings;

  /// Own baking tin: amounts converted by area (null = as in the recipe).
  BakingPan? _myPan;

  Future<void> _delete(Recipe recipe) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.confirmDeleteRecipe(recipe.title),
      confirmLabel: l10n.delete,
    );
    if (!ok || !mounted) return;
    // Variants stay: the first one becomes the new original.
    final all = ref.read(recipesProvider).value ?? const <Recipe>[];
    fire(
      ref
          .read(recipeRepositoryProvider)
          .deleteWithVariants(recipe.id, promoteOnDelete(recipe, all)),
    );
    if (recipe.photoPaths.isNotEmpty) {
      fire(ref.read(photoRepositoryProvider).deleteFiles(recipe.photoPaths));
    }
    context.pop();
    showSnack(context, l10n.recipeDeleted);
  }

  Future<void> _newVariant(Recipe recipe) async {
    final l10n = context.l10n;
    final name = (await showTextInputDialog(
      context,
      title: l10n.variantNew,
      label: l10n.variantNameLabel,
      hint: l10n.variantNameHint,
      helper: l10n.variantNewHelper,
      confirmLabel: l10n.variantCreate,
    ))?.trim();
    if (name == null || name.isEmpty || !mounted) return;
    fire(context.push(Routes.newVariant(recipe.id, name)));
  }

  void _toggleFavorite(Recipe recipe, bool on) {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    fire(
      ref.read(householdRepositoryProvider).setFavorite(uid, recipe.id, on: on),
    );
  }

  /// "Tags vorschlagen (KI)": suggestions to tick, then only the tags are
  /// saved (the nutrition estimate stays).
  Future<void> _suggestTags(Recipe recipe) async {
    final l10n = context.l10n;
    showSnack(context, l10n.tagsSuggesting);
    List<String> suggested;
    try {
      final extractor = await ref.read(recipeExtractorProvider.future);
      suggested = await extractor.suggestTags(
        [
          recipe.title,
          for (final l in recipe.ingredients) l.rawText,
          for (final s in recipe.steps) s.text,
        ].join('\n'),
        ref.read(tagsProvider),
      );
    } catch (e, st) {
      reportError(e, st);
      if (mounted) showSnack(context, l10n.tagsSuggestFailed);
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TagsDialog(current: recipe.tags, suggested: suggested),
    );
    if (chosen == null) return;
    fire(ref.read(recipeRepositoryProvider).setTags(recipe.id, chosen));
  }

  Future<void> _editCollections(Recipe recipe) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionsSheet(
        all: ref.read(collectionsProvider),
        selected: recipe.collections.toSet(),
      ),
    );
    if (result == null) return;
    fire(ref.read(recipeRepositoryProvider).setCollections(recipe.id, result));
  }

  /// Printable PDF of the recipe as shown (servings, tin, unit display);
  /// [share] sends the file instead of opening the print dialog.
  Future<void> _pdf(Recipe recipe, int servings, {bool share = false}) async {
    final l10n = context.l10n;
    Uint8List? photo;
    if (recipe.photoPaths.isNotEmpty) {
      try {
        photo = await ref
            .read(photoFileProvider(recipe.photoPaths.first).future)
            .then((f) => f.readAsBytes());
      } on Object {
        // Offline and not cached: the PDF comes without the photo.
      }
    }
    final pdf = await buildRecipePdf(
      recipe,
      labels: (
        ingredients: l10n.ingredientsTitle,
        steps: l10n.stepsTitle,
        notes: l10n.notesTitle,
        servings: l10n.servingsCount,
        prep: l10n.pdfPrep,
        cook: l10n.pdfCook,
        footer: l10n.pdfFooter,
      ),
      ingredients: ref.read(ingredientsByIdProvider),
      regularFont: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      boldFont: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      servings: servings,
      display: ref.read(unitDisplayProvider),
      photo: photo,
    );
    final printer = ref.read(recipePrinterProvider);
    final name = recipe.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    await (share
        ? printer.share(pdf, '$name.pdf')
        : printer.print(pdf, recipe.title));
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
    // Parts are bought as their whole (Eiweiß -> Eier, Zitronensaft ->
    // Zitronen).
    final missing = missingToBuy(
      coverage.recipe,
      ref.read(ingredientsByIdProvider),
      ref.read(pantryProvider).value ?? const {},
      servings: _servings ?? coverage.recipe.servings,
    );
    if (alreadyOnList(
      coverage.recipe.id,
      missing.map((m) => m.ingredient.id),
      current,
    )) {
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
      final knowAmount = need.missingBase != null;
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
    final stored = recipes?.where((r) => r.id == widget.recipeId).firstOrNull;
    if (stored == null || recipes == null) {
      return Scaffold(
        appBar: AppBar(),
        body: recipes == null
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off, message: l10n.noSearchResults),
      );
    }
    // Another tin: everything below (amounts, stock, shopping, cooking)
    // uses the converted recipe.
    final panFactor = (stored.pan != null && _myPan != null)
        ? stored.pan!.factorFor(_myPan!)
        : 1.0;
    final recipe = stored.scaledBy(panFactor);
    final family = variantFamily(stored, recipes);
    // A variant without own photos shows those of the original.
    final photos = stored.photoPaths.isEmpty
        ? family.first.photoPaths
        : stored.photoPaths;
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
    final isFavorite = ref.watch(favoritesProvider).contains(recipe.id);
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
            tooltip: isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
            onPressed: () => _toggleFavorite(recipe, !isFavorite),
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            color: isFavorite ? Colors.redAccent : null,
          ),
          IconButton(
            tooltip: l10n.addToMealPlan,
            onPressed: () => _planDay(recipe),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: l10n.edit,
            onPressed: () => context.push(Routes.editRecipe(recipe.id)),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<void>(
            tooltip: l10n.moreActions,
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _share(recipe, servings),
                child: ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l10n.shareRecipe),
                ),
              ),
              PopupMenuItem(
                onTap: () => fire(_pdf(recipe, servings)),
                child: ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(l10n.printRecipe),
                ),
              ),
              PopupMenuItem(
                onTap: () => fire(_pdf(recipe, servings, share: true)),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l10n.sharePdf),
                ),
              ),
              PopupMenuItem(
                onTap: () => sendRecipeToHousehold(context, ref, stored),
                child: ListTile(
                  leading: const Icon(Icons.send_outlined),
                  title: Text(l10n.sendRecipeMenu),
                ),
              ),
              PopupMenuItem(
                onTap: () => fire(_suggestTags(stored)),
                child: ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: Text(l10n.tagsSuggest),
                ),
              ),
              PopupMenuItem(
                onTap: () => fire(_newVariant(stored)),
                child: ListTile(
                  leading: const Icon(Icons.call_split),
                  title: Text(l10n.variantNew),
                ),
              ),
              PopupMenuItem(
                onTap: () => _editCollections(recipe),
                child: ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(l10n.collectionsEdit),
                ),
              ),
              PopupMenuItem(
                onTap: () => _delete(recipe),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.delete),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (family.length > 1) ...[
            _VariantSwitch(family: family, currentId: stored.id),
            const SizedBox(height: 8),
          ],
          if (photos.isNotEmpty || pendingPhotos.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: PageView(
                  children: [
                    for (final p in photos) StorageImage(path: p),
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
              for (final c in recipe.collections)
                ActionChip(
                  avatar: const Icon(Icons.collections_bookmark_outlined),
                  label: Text(c),
                  onPressed: () => _editCollections(recipe),
                ),
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
                icon: Icon(Icons.remove, semanticLabel: context.l10n.decrease),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$servings', style: theme.textTheme.titleLarge),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _servings = servings + 1),
                icon: Icon(Icons.add, semanticLabel: context.l10n.increase),
              ),
            ],
          ),
          if (stored.pan case final pan?)
            _PanRow(
              recipePan: pan,
              myPan: _myPan,
              factor: panFactor,
              onChanged: (p) => setState(() => _myPan = p),
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
                      extra: (servings, panFactor),
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

/// "Backform im Rezept: Ø 26 cm" with "Andere Form" (area ratio).
class _PanRow extends StatelessWidget {
  const _PanRow({
    required this.recipePan,
    required this.myPan,
    required this.factor,
    required this.onChanged,
  });

  final BakingPan recipePan;
  final BakingPan? myPan;
  final double factor;
  final ValueChanged<BakingPan?> onChanged;

  Future<void> _choose(BuildContext context) async {
    final pan = await showDialog<BakingPan>(
      context: context,
      builder: (_) => _PanDialog(initial: myPan ?? recipePan),
    );
    if (pan != null) onChanged(pan);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mine = myPan;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cake_outlined),
      title: Text(l10n.panRecipe(panLabel(context, recipePan))),
      subtitle: mine == null
          ? null
          : Text(
              l10n.panConverted(
                panLabel(context, mine),
                formatAmount(factor, fractions: false),
              ),
            ),
      trailing: mine == null
          ? TextButton(
              onPressed: () => _choose(context),
              child: Text(l10n.panConvert),
            )
          : IconButton(
              tooltip: l10n.panReset,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
      onTap: () => _choose(context),
    );
  }
}

class _PanDialog extends StatefulWidget {
  const _PanDialog({required this.initial});

  final BakingPan initial;

  @override
  State<_PanDialog> createState() => _PanDialogState();
}

class _PanDialogState extends State<_PanDialog> {
  late final _input = PanInput(widget.initial);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _input.value;
    return AlertDialog(
      title: Text(l10n.panConvertTitle),
      content: PanFields(
        input: _input,
        allowNone: false,
        onChanged: () => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: value == null
              ? null
              : () => Navigator.pop(context, _input.value ?? value),
          child: Text(l10n.panConvertApply),
        ),
      ],
    );
  }
}

/// Current tags plus AI suggestions, each as a chip to keep or drop.
class _TagsDialog extends StatefulWidget {
  const _TagsDialog({required this.current, required this.suggested});

  final List<String> current;
  final List<String> suggested;

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late final List<String> _all = [
    ...widget.current,
    for (final t in widget.suggested)
      if (!widget.current.any((c) => c.toLowerCase() == t.toLowerCase())) t,
  ];
  late final Set<String> _chosen = {..._all};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.tagsSuggestTitle),
      content: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final t in _all)
            FilterChip(
              label: Text('#$t'),
              selected: _chosen.contains(t),
              onSelected: (on) =>
                  setState(() => on ? _chosen.add(t) : _chosen.remove(t)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [
            for (final t in _all)
              if (_chosen.contains(t)) t,
          ]),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// "Original · vegan · für 2": switches between the variants of a recipe.
class _VariantSwitch extends StatelessWidget {
  const _VariantSwitch({required this.family, required this.currentId});

  final List<Recipe> family;
  final String currentId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          Icon(
            Icons.call_split,
            semanticLabel: l10n.variantsTitle,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          for (final (i, r) in family.indexed)
            ChoiceChip(
              label: Text(i == 0 ? l10n.variantOriginal : r.variantLabel),
              selected: r.id == currentId,
              onSelected: (_) {
                if (r.id != currentId) context.replace(Routes.recipe(r.id));
              },
            ),
        ],
      ),
    );
  }
}
