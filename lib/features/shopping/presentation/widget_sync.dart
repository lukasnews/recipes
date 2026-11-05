import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/display_units.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../mealplan/data/meal_plan_repository.dart';
import '../../mealplan/domain/meal_plan_day.dart';
import '../../pantry/domain/frozen_meal.dart';
import '../../recipes/domain/recipe.dart';
import '../data/home_screen_widget.dart';
import '../domain/shopping_item.dart';
import 'shopping_list_screen.dart';

/// Widget rows: open items by aisle, linked items with their current name;
/// the id lets the widget check an item off.
List<WidgetRow> widgetRows(
  List<ShoppingItem> shopping,
  Map<String, Ingredient> ingredients,
  UnitDisplay display, [
  List<Aisle> order = Aisle.values,
]) {
  final open = shopping.where((i) => !i.checked).toList()
    ..sort((a, b) => order.indexOf(a.aisle).compareTo(order.indexOf(b.aisle)));
  return [
    for (final i in open)
      (
        id: i.id,
        text: [
          shoppingQuantity(i, display),
          ingredients[i.ingredientId]?.name ?? i.text,
        ].where((s) => s.isNotEmpty).join(' '),
      ),
  ];
}

/// Widget lines (text only), see [widgetRows].
List<String> widgetLines(
  List<ShoppingItem> shopping,
  Map<String, Ingredient> ingredients,
  UnitDisplay display, [
  List<Aisle> order = Aisle.values,
]) => [
  for (final r in widgetRows(shopping, ingredients, display, order)) r.text,
];

/// Meal plan widget data: titles per day from [from] for [days] days
/// ("" when nothing is planned), recipes first, then frozen dishes.
Map<String, String> planWidgetDays(
  Map<String, MealPlanDay> plan,
  Map<String, Recipe> recipes,
  Map<String, FrozenMeal> frozen,
  DateTime from, {
  int days = 14,
}) => {
  for (var i = 0; i < days; i++)
    dayKey(DateTime(from.year, from.month, from.day + i)): () {
      final day = plan[dayKey(DateTime(from.year, from.month, from.day + i))];
      return [
        for (final id in day?.recipeIds ?? const <String>[])
          ?recipes[id]?.title,
        for (final id in day?.frozenMealIds ?? const <String>[])
          ?frozen[id]?.title,
      ].join(', ');
    }(),
};

/// Keeps the home screen widget up to date while the app runs and opens
/// the shopping list when the widget is tapped.
class WidgetSync extends ConsumerStatefulWidget {
  const WidgetSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends ConsumerState<WidgetSync> {
  static const maxLines = 10;
  StreamSubscription<Uri?>? _clicks;
  WidgetContent? _last;

  @override
  void initState() {
    super.initState();
    final widget = ref.read(homeScreenWidgetProvider);
    unawaited(widget.initialClick().then(_open).catchError((_) {}));
    _clicks = widget.clicks().listen(_open, onError: (_) {});
  }

  void _open(Uri? uri) {
    if (!mounted) return;
    switch (uri?.host) {
      case 'shopping':
        context.go(Routes.shopping);
      case 'mealplan':
        context.go(Routes.mealPlan);
    }
  }

  @override
  void dispose() {
    unawaited(_clicks?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shopping = ref.watch(shoppingProvider).value;
    if (shopping != null) {
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
      final days = planWidgetDays(plan, recipes, frozen, DateTime.now());
      final todayText = days.values.first;
      final rows = widgetRows(
        shopping,
        ref.watch(ingredientsByIdProvider),
        ref.watch(unitDisplayProvider),
        ref.watch(aisleOrderProvider),
      );
      final lines = [for (final r in rows) r.text];
      final content = WidgetContent(
        householdId: ref.watch(householdIdProvider),
        rows: rows,
        title: l10n.widgetTitle(lines.length),
        today: todayText.isEmpty ? null : l10n.widgetToday(todayText),
        plan: days,
        items: lines.isEmpty
            ? l10n.widgetListEmpty
            : [
                ...lines.take(maxLines).map((l) => '• $l'),
                if (lines.length > maxLines)
                  l10n.widgetMore(lines.length - maxLines),
              ].join('\n'),
      );
      if (content != _last) {
        _last = content;
        fire(ref.read(homeScreenWidgetProvider).update(content));
      }
    }
    return widget.child;
  }
}
