import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../pantry/domain/frozen_meal.dart';
import '../../recipes/domain/recipe.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_day.dart';
import '../domain/week_shopping.dart';
import '../domain/week_suggestion.dart';
import 'needs_dialog.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  DateTime _week = startOfWeek(DateTime.now());

  Future<void> _addRecipe(DateTime day) async {
    // Cookies aren't a meal.
    final recipes = [
      for (final r in ref.read(recipesProvider).value ?? const <Recipe>[])
        if (r.category != RecipeCategories.cookies) r,
    ];
    final frozen = ref.read(frozenMealsProvider).value ?? const <FrozenMeal>[];
    final picked = await showModalBottomSheet<Object>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _RecipePicker(recipes: recipes, frozen: frozen),
    );
    final repo = ref.read(mealPlanRepositoryProvider);
    switch (picked) {
      case Recipe(:final id):
        fire(repo.add(dayKey(day), id));
      case FrozenMeal(:final id):
        fire(repo.addFrozen(dayKey(day), id));
    }
  }

  /// Fills the free days of the shown week (today onwards) with
  /// suggestions, after a preview.
  Future<void> _suggestWeek() async {
    final l10n = context.l10n;
    final plan = ref.read(mealPlanProvider).value ?? const {};
    final today = dayKey(DateTime.now());
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(_week.year, _week.month, _week.day + i),
    ].where((d) => dayKey(d).compareTo(today) >= 0).toList();
    final weekPlans = [for (final d in days) plan[dayKey(d)]];
    final free = [
      for (final d in days)
        if (plan[dayKey(d)]?.isEmpty ?? true) dayKey(d),
    ];
    final suggestions = suggestWeek(
      freeDays: free,
      recipes: ref.read(recipesProvider).value ?? const <Recipe>[],
      ingredients: ref.read(ingredientsByIdProvider),
      pantry: ref.read(pantryProvider).value ?? const {},
      stats: ref.read(cookStatsProvider).value ?? const {},
      frozen: ref.read(frozenMealsProvider).value ?? const <FrozenMeal>[],
      now: DateTime.now(),
      plannedIds: {for (final p in weekPlans) ...?p?.recipeIds},
      plannedFrozenIds: {for (final p in weekPlans) ...?p?.frozenMealIds},
    );
    if (suggestions.isEmpty) {
      showSnack(
        context,
        free.isEmpty ? l10n.suggestWeekFull : l10n.suggestWeekNoRecipes,
      );
      return;
    }
    final dayFormat = DateFormat('EEE, d. M.', 'de');
    final selected = {for (var i = 0; i < suggestions.length; i++) i};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.suggestWeekTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(l10n.suggestWeekHint),
                for (final (i, s) in suggestions.indexed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(i),
                    onChanged: (v) => setState(
                      () => v == true ? selected.add(i) : selected.remove(i),
                    ),
                    secondary: s.frozen == null
                        ? null
                        : const Icon(Icons.ac_unit),
                    title: Text(s.title),
                    subtitle: Text(dayFormat.format(DateTime.parse(s.dayKey))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.suggestWeekApply),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final repo = ref.read(mealPlanRepositoryProvider);
    for (final (i, s) in suggestions.indexed) {
      if (!selected.contains(i)) continue;
      fire(
        s.recipe != null
            ? repo.add(s.dayKey, s.recipe!.id)
            : repo.addFrozen(s.dayKey, s.frozen!.id),
      );
    }
  }

  /// Takes one portion of a planned freezer dish out of the freezer.
  Future<void> _takePortion(FrozenMeal meal) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: meal.title,
      message: l10n.frozenTakeQuestion(meal.portions),
      confirmLabel: l10n.frozenTake,
    );
    if (!ok || !mounted) return;
    fire(ref.read(frozenMealRepositoryProvider).changePortions(meal, -1));
    showSnack(context, l10n.frozenTaken(meal.title));
  }

  /// Puts what the planned recipes of this week (today onwards) still need
  /// on the shopping list, after a review with checkboxes.
  Future<void> _shopWeek() async {
    final l10n = context.l10n;
    final plan = ref.read(mealPlanProvider).value ?? const {};
    final recipes = {
      for (final r in ref.read(recipesProvider).value ?? const <Recipe>[])
        r.id: r,
    };
    final today = DateTime.now();
    final todayKey = dayKey(today);
    final planned = [
      for (var i = 0; i < 7; i++)
        for (final id
            in plan[dayKey(DateTime(_week.year, _week.month, _week.day + i))]
                    ?.recipeIds ??
                const <String>[])
          if (dayKey(DateTime(_week.year, _week.month, _week.day + i))
                      .compareTo(todayKey) >=
                  0 &&
              recipes[id] != null)
            recipes[id]!,
    ];
    final needs = weekShoppingNeeds(
      planned,
      ref.read(ingredientsByIdProvider),
      ref.read(pantryProvider).value ?? const {},
    );
    if (needs.isEmpty) {
      showSnack(
        context,
        planned.isEmpty ? l10n.weekNothingPlanned : l10n.weekAllInStock,
      );
      return;
    }
    await shopNeeds(
      context,
      ref,
      needs,
      title: l10n.weekShopTitle,
      hint: l10n.weekShopHint(planned.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final plan = ref.watch(mealPlanProvider).value ?? const {};
    final recipes = {
      for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
        r.id: r,
    };
    final frozen = {
      for (final m
          in ref.watch(frozenMealsProvider).value ?? const <FrozenMeal>[])
        m.id: m,
    };
    final today = DateTime.now();
    final dayFormat = DateFormat('EEEE, d. MMMM', 'de');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMealPlan),
        actions: [
          IconButton(
            tooltip: l10n.suggestWeekTitle,
            onPressed: _suggestWeek,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: l10n.weekShopTitle,
            onPressed: _shopWeek,
            icon: const Icon(Icons.add_shopping_cart),
          ),
          const ProfileButton(),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.previousWeek,
                onPressed: () => setState(
                  () => _week = _week.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _week = startOfWeek(DateTime.now())),
                  child: Text(
                    l10n.weekOf(DateFormat('d. MMMM', 'de').format(_week)),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.nextWeek,
                onPressed: () =>
                    setState(() => _week = _week.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: 7,
              itemBuilder: (context, i) {
                final day = DateTime(_week.year, _week.month, _week.day + i);
                final key = dayKey(day);
                final dayPlan = plan[key] ?? const MealPlanDay();
                final ids = dayPlan.recipeIds;
                final isToday = key == dayKey(today);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: isToday ? theme.colorScheme.secondaryContainer : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isToday
                                    ? '${l10n.today} · ${dayFormat.format(day)}'
                                    : dayFormat.format(day),
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.addRecipeToDay,
                              onPressed: () => _addRecipe(day),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (dayPlan.isEmpty)
                          Text(
                            l10n.nothingPlanned,
                            style: theme.textTheme.bodySmall,
                          ),
                        for (final id in ids)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(recipes[id]?.title ?? '…'),
                            onTap: recipes[id] == null
                                ? null
                                : () => context.go(Routes.recipe(id)),
                            trailing: IconButton(
                              tooltip: l10n.delete,
                              onPressed: () => fire(
                                ref
                                    .read(mealPlanRepositoryProvider)
                                    .remove(key, id),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        for (final id in dayPlan.frozenMealIds)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.ac_unit),
                            title: Text(
                              frozen[id]?.title ?? l10n.frozenMealGone,
                            ),
                            subtitle: frozen[id] == null
                                ? null
                                : Text(
                                    l10n.frozenPortions(frozen[id]!.portions),
                                  ),
                            onTap: frozen[id] == null
                                ? null
                                : () => _takePortion(frozen[id]!),
                            trailing: IconButton(
                              tooltip: l10n.delete,
                              onPressed: () => fire(
                                ref
                                    .read(mealPlanRepositoryProvider)
                                    .removeFrozen(key, id),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.recipes, required this.frozen});

  final List<Recipe> recipes;
  final List<FrozenMeal> frozen;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    bool hit(String title) => title.toLowerCase().contains(_q.toLowerCase());
    final list = widget.recipes.where((r) => hit(r.title)).toList();
    final frozen = widget.frozen.where((m) => hit(m.title)).toList();
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.pickRecipe,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: list.isEmpty && frozen.isEmpty
                  ? Center(child: Text(l10n.recipesEmpty))
                  : ListView(
                      children: [
                        if (frozen.isNotEmpty) ...[
                          header(l10n.fromFreezer),
                          for (final m in frozen)
                            ListTile(
                              leading: const Icon(Icons.ac_unit),
                              title: Text(m.title),
                              subtitle: Text(l10n.frozenPortions(m.portions)),
                              onTap: () => Navigator.pop(context, m),
                            ),
                          if (list.isNotEmpty) header(l10n.navRecipes),
                        ],
                        for (final r in list)
                          ListTile(
                            title: Text(r.title),
                            subtitle: Text(l10n.category(r.category)),
                            onTap: () => Navigator.pop(context, r),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
