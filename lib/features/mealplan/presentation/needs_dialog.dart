import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../shopping/domain/shopping_item.dart';
import '../domain/week_shopping.dart';

/// Review with check boxes, then the ticked needs onto the shopping list.
/// Ingredients already open on the list are offered but not ticked.
Future<void> shopNeeds(
  BuildContext context,
  WidgetRef ref,
  List<ShoppingNeed> needs, {
  required String title,
  required String hint,
}) async {
  final l10n = context.l10n;
  // Already open on the list: offered, but not ticked.
  final onList = {
    for (final i in ref.read(shoppingProvider).value ?? const <ShoppingItem>[])
      if (!i.checked) ?i.ingredientId,
  };
  final selected = {
    for (final (i, n) in needs.indexed)
      if (!onList.contains(n.ingredient.id)) i,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(hint),
              for (final (i, n) in needs.indexed)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(i),
                  onChanged: (v) => setState(
                    () => v == true ? selected.add(i) : selected.remove(i),
                  ),
                  title: Text(n.ingredient.name),
                  subtitle: Text(
                    [
                      if (n.missingBase != null)
                        formatBaseAmount(n.missingBase!, n.ingredient.baseUnit),
                      if (onList.contains(n.ingredient.id)) l10n.alreadyOnList,
                    ].join(' · '),
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
  if (ok != true || !context.mounted) return;
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
