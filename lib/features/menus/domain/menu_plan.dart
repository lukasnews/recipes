import '../../ingredients/domain/ingredient.dart';
import '../../mealplan/domain/week_shopping.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../recipes/domain/recipe.dart';
import 'menu.dart';

/// Minutes after the first course is served: starter, then main (with its
/// sides) after 30 min, dessert after 75 min.
const courseOffsetMinutes = {
  Course.starter: 0,
  Course.main: 30,
  Course.side: 30,
  Course.dessert: 75,
  Course.other: 0,
};

enum StepKind { prepare, cook, serve }

class TimelineStep {
  const TimelineStep(this.at, this.recipe, this.kind, [this.minutes = 0]);

  final DateTime at;
  final Recipe recipe;
  final StepKind kind;

  /// Duration of preparing / cooking.
  final int minutes;
}

/// "16:45 Gulasch vorbereiten (20 Min.)", "17:05 Gulasch kochen (90 Min.)",
/// "19:30 Gulasch servieren": counted back from [serveAt] per course.
/// Recipes without times only get the serve step and are listed in
/// `untimed`.
({List<TimelineStep> steps, List<Recipe> untimed}) menuTimeline(
  Menu menu,
  Map<String, Recipe> recipes,
  DateTime serveAt,
) {
  final steps = <TimelineStep>[];
  final untimed = <Recipe>[];
  for (final c in menu.ordered) {
    final r = recipes[c.recipeId];
    if (r == null) continue;
    final ready = serveAt.add(
      Duration(minutes: courseOffsetMinutes[c.course]!),
    );
    final cook = r.cookMinutes ?? 0;
    final prep = r.prepMinutes ?? 0;
    if (cook <= 0 && prep <= 0) untimed.add(r);
    final cookStart = ready.subtract(Duration(minutes: cook));
    if (cook > 0) steps.add(TimelineStep(cookStart, r, StepKind.cook, cook));
    if (prep > 0) {
      steps.add(
        TimelineStep(
          cookStart.subtract(Duration(minutes: prep)),
          r,
          StepKind.prepare,
          prep,
        ),
      );
    }
    steps.add(TimelineStep(ready, r, StepKind.serve));
  }
  steps.sort((a, b) {
    final t = a.at.compareTo(b.at);
    return t != 0 ? t : a.kind.index.compareTo(b.kind.index);
  });
  return (steps: steps, untimed: untimed);
}

/// Serving time on the menu's date (or [today]) from "HH:mm".
DateTime? menuServeTime(Menu menu, DateTime today) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(menu.serveAt ?? '');
  if (m == null) return null;
  final day = DateTime.tryParse(menu.date ?? '') ?? today;
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
  );
}

/// What all courses still need for [Menu.servings] people, pantry
/// subtracted once.
List<ShoppingNeed> menuShoppingNeeds(
  Menu menu,
  Map<String, Recipe> recipes,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry,
) => weekShoppingNeeds(
  [
    for (final c in menu.courses)
      if (recipes[c.recipeId] case final r?)
        r.scaledBy(menu.servings / (r.servings > 0 ? r.servings : 1)),
  ],
  ingredients,
  pantry,
);
