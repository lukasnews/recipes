import '../../../core/units/display_units.dart';
import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import 'recipe.dart';

/// Localized headings for [recipeShareText].
typedef ShareLabels = ({
  String Function(int servings) servings,
  String ingredients,
  String steps,
});

/// Plain-text recipe for messengers: title, servings, ingredients scaled to
/// [servings] and shown in [display] units, numbered steps, source link.
String recipeShareText(
  Recipe recipe, {
  required ShareLabels labels,
  required Map<String, Ingredient> ingredients,
  UnitDisplay display = UnitDisplay.original,
  int? servings,
}) {
  final target = servings ?? recipe.servings;
  final b = StringBuffer()
    ..writeln(recipe.title)
    ..writeln(labels.servings(target));
  if (recipe.ingredients.isNotEmpty) {
    b
      ..writeln()
      ..writeln('${labels.ingredients}:');
    for (final line in recipe.ingredients) {
      final id = line.ingredientId;
      final name =
          (id == null ? null : ingredients[id]?.name) ??
          line.name ??
          line.rawText;
      final amount = line.amount == null
          ? null
          : scaleAmount(line.amount!, recipe.servings, target);
      final qty = displayQuantity(amount, line.unit, display);
      final note = line.note == null ? '' : ', ${line.note}';
      b.writeln('• ${[if (qty.isNotEmpty) qty, name].join(' ')}$note');
    }
  }
  if (recipe.steps.isNotEmpty) {
    b
      ..writeln()
      ..writeln('${labels.steps}:');
    for (final (i, step) in recipe.steps.indexed) {
      b.writeln('${i + 1}. ${step.text}');
    }
  }
  final url = recipe.sourceUrl;
  if (url != null) {
    b
      ..writeln()
      ..writeln(url);
  }
  return b.toString().trimRight();
}
