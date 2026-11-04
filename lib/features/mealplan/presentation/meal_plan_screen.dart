import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/meal_plan_day.dart';
import '../domain/week_shopping.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  DateTime _week = startOfWeek(DateTime.now());

  Future<void> _addRecipe(DateTime day) async {
    final recipes = ref.read(recipesProvider).value ?? const <Recipe>[];
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _RecipePicker(recipes: recipes),
    );
    if (picked == null) return;
    fire(ref.read(mealPlanRepositoryProvider).add(dayKey(day), picked.id));
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
            in plan[dayKey(DateTime(_week.year, _week.month, _week.day + i))] ??
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
    final selected = {for (var i = 0; i < needs.length; i++) i};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.weekShopTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(l10n.weekShopHint(planned.length)),
                for (final (i, n) in needs.indexed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(i),
                    onChanged: (v) => setState(
                      () => v == true ? selected.add(i) : selected.remove(i),
                    ),
                    title: Text(n.ingredient.name),
                    subtitle: n.missingBase == null
                        ? null
                        : Text(
                            formatBaseAmount(
                              n.missingBase!,
                              n.ingredient.baseUnit,
                            ),
                          ),
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
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(shoppingRepositoryProvider);
    final current = ref.read(shoppingProvider).value ?? const [];
    var count = 0;
    for (final (i, n) in needs.indexed) {
      if (!selected.contains(i)) continue;
      final ing = n.ingredient;
      fire(
        repo.add(
          text: ing.name,
          current: current,
          ingredientId: ing.id,
          amount: n.missingBase,
          unit: n.missingBase == null
              ? null
              : (ing.baseUnit == BaseUnit.pcs ? 'Stk.' : ing.baseUnit.name),
          aisle: ing.aisle,
        ),
      );
      count++;
    }
    showSnack(context, l10n.buyMissingDone(count));
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
    final today = DateTime.now();
    final dayFormat = DateFormat('EEEE, d. MMMM', 'de');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMealPlan),
        actions: [
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
                final ids = plan[key] ?? const [];
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
                        if (ids.isEmpty)
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
  const _RecipePicker({required this.recipes});

  final List<Recipe> recipes;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = widget.recipes
        .where((r) => r.title.toLowerCase().contains(_q.toLowerCase()))
        .toList();
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
              child: list.isEmpty
                  ? Center(child: Text(l10n.recipesEmpty))
                  : ListView(
                      children: [
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
