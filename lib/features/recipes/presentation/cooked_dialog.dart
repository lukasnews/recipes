import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../pantry/presentation/stock_actions.dart';
import '../domain/recipe.dart';
import '../domain/recipe_stock.dart';

String _unitLabel(BaseUnit u) => u == BaseUnit.pcs ? 'Stk.' : u.name;

/// Shows planned deductions (editable), then books them with increments and
/// a cook log entry. Offers undo.
Future<void> showCookedDialog(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
  int servings,
) async {
  final l10n = context.l10n;
  final ingredients = {...ref.read(ingredientsByIdProvider)};
  final pantry = ref.read(pantryProvider).value ?? const {};
  // Never skip silently: ask once for each missing conversion (stored on
  // the ingredient); cancelled ones stay in the dialog with 0 to fill in.
  final stillUnknown = <String>{};
  for (final MapEntry(key: id, value: units) in unconvertibleUnits(
    recipe,
    ingredients,
  ).entries) {
    for (final unit in units) {
      if (!context.mounted) return;
      final ing = ingredients[id]!;
      final factor = await askConversion(context, ref, ing, unit);
      if (factor == null) {
        stillUnknown.add(id);
      } else {
        ingredients[id] = ing.copyWith(
          conversions: {...ing.conversions, unit: factor},
        );
      }
    }
  }
  if (!context.mounted) return;
  final computed = plannedDeductions(recipe, ingredients, servings: servings);
  final planned = [
    ...computed,
    for (final id in stillUnknown)
      if (!computed.any((d) => d.ingredient.id == id))
        Deduction(ingredient: ingredients[id]!, amountBase: 0),
  ];
  final controllers = {
    for (final d in planned)
      d.ingredient.id: TextEditingController(
        text: formatAmount(d.amountBase, fractions: false),
      ),
  };

  final leftovers = TextEditingController(text: '0');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.cookedTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(planned.isEmpty ? l10n.cookedNothing : l10n.cookedIntro),
            const SizedBox(height: 12),
            for (final d in planned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: controllers[d.ingredient.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: d.ingredient.name,
                    suffixText: _unitLabel(d.ingredient.baseUnit),
                    helperText: l10n.inStock(
                      formatBaseAmount(
                        pantry[d.ingredient.id]?.amount ?? 0,
                        d.ingredient.baseUnit,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: leftovers,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.freezeLeftovers,
                prefixIcon: const Icon(Icons.ac_unit),
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
          child: Text(l10n.cookedConfirm),
        ),
      ],
    ),
  );

  final requested = {
    for (final e in controllers.entries)
      e.key: parseUserNumber(e.value.text) ?? 0,
  };
  final frozenPortions = int.tryParse(leftovers.text.trim()) ?? 0;
  // Not disposed here: the dialog may still be animating out and use them;
  // they hold no resources and are garbage collected.
  if (confirmed != true || !context.mounted) return;

  if (frozenPortions > 0) {
    fire(
      ref
          .read(frozenMealRepositoryProvider)
          .add(
            title: recipe.title,
            portions: frozenPortions,
            recipeId: recipe.id,
          ),
    );
  }

  var clamped = false;
  final applied = <String, double>{};
  requested.forEach((id, amount) {
    final stock = pantry[id]?.amount;
    final a = clampDeduction(amount, stock);
    if (a < amount) clamped = true;
    if (a > 0) applied[id] = a;
  });

  final repo = ref.read(recipeRepositoryProvider);
  final logId = repo.cook(
    recipe: recipe,
    servings: servings,
    deductions: applied,
    onCommit: fire,
  );
  checkMinStock(context, ref, {
    for (final e in applied.entries)
      e.key: (pantry[e.key]?.amount ?? 0) - e.value,
  });
  if (!context.mounted) return;
  showSnack(
    context,
    clamped ? '${l10n.cookedDone}. ${l10n.cookedClamped}' : l10n.cookedDone,
    actionLabel: l10n.undo,
    onAction: () => fire(repo.undoCook(logId, applied)),
  );
}
