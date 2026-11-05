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

/// Long press on − / +: take out or add any amount in any unit (5 Stk.,
/// 300 g). Units the ingredient can't convert ask once.
Future<void> adjustStockBy(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient, {
  required bool takeOut,
}) async {
  final result = await showDialog<(double, String)>(
    context: context,
    builder: (_) => _AmountDialog(ingredient: ingredient, takeOut: takeOut),
  );
  if (result == null || !context.mounted) return;
  final (amount, unit) = result;
  var base = ingredient.toBase(
    amount,
    unit == 'Stk.' && ingredient.baseUnit == BaseUnit.pcs ? null : unit,
  );
  if (base == null) {
    final factor = await askConversion(context, ref, ingredient, unit);
    if (factor == null || !context.mounted) return;
    base = amount * factor;
  }
  adjustStock(context, ref, ingredient, takeOut ? -base : base);
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.ingredient, required this.takeOut});

  final Ingredient ingredient;
  final bool takeOut;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amount = TextEditingController();
  late final List<String> _units = {
    ...widget.ingredient.unitChoices,
    'g',
    'kg',
    'ml',
    'l',
    'Stk.',
  }.toList();
  late String _unit = _units.first;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    final v = parseUserNumber(_amount.text);
    if (v == null || v <= 0) return;
    Navigator.pop(context, (v, _unit));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = widget.ingredient.name;
    return AlertDialog(
      title: Text(
        widget.takeOut
            ? l10n.stockTakeOutTitle(name)
            : l10n.stockAddTitle(name),
      ),
      content: Row(
        spacing: 12,
        children: [
          Expanded(
            child: TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.amountLabel),
              onSubmitted: (_) => _done(),
            ),
          ),
          SizedBox(
            width: 96,
            child: DropdownButtonFormField<String>(
              initialValue: _unit,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.unitLabel),
              items: [
                for (final u in _units)
                  DropdownMenuItem(value: u, child: Text(u)),
              ],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _done,
          child: Text(widget.takeOut ? l10n.stockTakeOut : l10n.stockAdd),
        ),
      ],
    );
  }
}
