import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../ingredients/domain/ingredient.dart';

/// Puts ingredients whose new stock is below their minimum on the shopping
/// list (once, no duplicates). [newAmounts]: ingredient id -> new amount.
void checkMinStock(
  BuildContext context,
  WidgetRef ref,
  Map<String, double> newAmounts,
) {
  final pantry = ref.read(pantryProvider).value ?? const {};
  final shopping = ref.read(shoppingProvider).value ?? const [];
  final ingredients = ref.read(ingredientsByIdProvider);
  final repo = ref.read(shoppingRepositoryProvider);
  for (final e in newAmounts.entries) {
    final min = pantry[e.key]?.minAmount;
    final ing = ingredients[e.key];
    if (min == null || ing == null || e.value >= min) continue;
    final onList = shopping.any((s) => !s.checked && s.ingredientId == ing.id);
    if (onList) continue;
    fire(
      repo.add(
        text: ing.name,
        current: shopping,
        ingredientId: ing.id,
        amount: min - e.value,
        unit: ing.baseUnit == BaseUnit.pcs ? 'Stk.' : ing.baseUnit.name,
        aisle: ing.aisle,
      ),
    );
    if (context.mounted) {
      showSnack(context, context.l10n.addedToShoppingMin(ing.name));
    }
  }
}

/// Changes stock by [delta] (clamped so it never drops below 0).
void adjustStock(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
  double delta,
) {
  final current = ref.read(pantryProvider).value?[ingredient.id]?.amount ?? 0;
  final applied = delta < 0 && -delta > current ? -current : delta;
  if (applied == 0) return;
  fire(ref.read(pantryRepositoryProvider).changeAmount(ingredient.id, applied));
  if (applied < 0) {
    checkMinStock(context, ref, {ingredient.id: current + applied});
  }
}

/// Asks once for a missing conversion and stores it on the ingredient.
Future<double?> askConversion(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
  String unit,
) async {
  final l10n = context.l10n;
  final base = ingredient.baseUnit == BaseUnit.pcs
      ? 'Stk.'
      : ingredient.baseUnit.name;
  final text = await showTextInputDialog(
    context,
    title: l10n.conversionAskTitle,
    label: l10n.conversionAsk(base, ingredient.name, unit),
    suffix: base,
    confirmLabel: l10n.save,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );
  final value = text == null ? null : parseUserNumber(text);
  if (value == null || value <= 0) return null;
  fire(
    ref
        .read(ingredientRepositoryProvider)
        .save(
          ingredient.copyWith(
            conversions: {...ingredient.conversions, unit: value},
          ),
        ),
  );
  return value;
}
