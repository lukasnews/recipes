import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/meal_plan_day.dart';

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
        actions: const [ProfileButton()],
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
