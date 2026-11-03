import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../ingredients/domain/ingredient_factory.dart';
import '../../ingredients/presentation/ingredient_picker.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/presentation/stock_actions.dart';
import '../domain/pantry_transfer.dart';
import '../domain/shopping_item.dart';

/// Review checked shopping items before they go into the pantry.
Future<void> showPantryTransferSheet(
  BuildContext context,
  List<ShoppingItem> items,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _TransferSheet(items: items),
);

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({required this.items});

  final List<ShoppingItem> items;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  late final List<TransferLine> _lines = planTransfer(
    widget.items,
    ref.read(ingredientsByIdProvider),
    ref.read(ingredientMatcherProvider),
  );
  late final _amounts = [
    for (final l in _lines)
      TextEditingController(
        text: l.amount == null ? '' : formatAmount(l.amount!, fractions: false),
      ),
  ];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _amounts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _link(int i) async {
    final line = _lines[i];
    final choice = await pickIngredient(context, initialQuery: line.item.text);
    if (choice == null) return;
    var ing = choice.ingredient;
    if (ing == null && choice.newName != null) {
      final repo = ref.read(ingredientRepositoryProvider);
      ing = newIngredient(repo.newId(), choice.newName!, unit: line.unit);
      fire(repo.save(ing));
    }
    if (ing == null) return;
    setState(() {
      line.ingredient = ing;
      if (!ing!.unitChoices.contains(line.unit)) {
        line.unit = ing.unitChoices.first;
      }
      line.location = defaultLocation(ing.aisle);
    });
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final stock = <String, (double, StorageLocation)>{};
    for (final (i, line) in _lines.indexed) {
      line.amount = parseUserNumber(_amounts[i].text);
      final ing = line.ingredient;
      if (ing == null || line.amount == null || line.amount! <= 0) continue;
      var base = line.baseAmount;
      if (base == null && line.unit != null) {
        // Missing conversion: ask once, it is stored on the ingredient.
        final factor = await askConversion(context, ref, ing, line.unit!);
        if (!mounted) return;
        if (factor == null) continue;
        base = line.amount! * factor;
      }
      if (base == null) continue;
      final prev = stock[ing.id]?.$1 ?? 0;
      stock[ing.id] = (prev + base, line.location);
    }
    fire(
      ref
          .read(shoppingRepositoryProvider)
          .transferToPantry(
            stock: stock,
            removeItemIds: _lines.map((l) => l.item.id),
          ),
    );
    if (!mounted) return;
    showSnack(context, context.l10n.transferDone(stock.length));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.transferTitle, style: theme.textTheme.titleLarge),
            subtitle: Text(l10n.transferHint),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _lines.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => _lineTile(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                child: Text(l10n.transferConfirm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineTile(int i) {
    final l10n = context.l10n;
    final line = _lines[i];
    final ing = line.ingredient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ing?.name ?? line.item.text),
          subtitle: ing == null
              ? Text(
                  l10n.transferUnlinked,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : null,
          trailing: TextButton(
            onPressed: () => _link(i),
            child: Text(ing == null ? l10n.transferLink : l10n.edit),
          ),
        ),
        if (ing != null)
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _amounts[i],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.amountLabel),
                ),
              ),
              SizedBox(
                width: 96,
                child: DropdownButtonFormField<String>(
                  initialValue: ing.unitChoices.contains(line.unit)
                      ? line.unit
                      : ing.unitChoices.first,
                  decoration: InputDecoration(labelText: l10n.unitLabel),
                  items: [
                    for (final u in ing.unitChoices)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => line.unit = v),
                ),
              ),
              SizedBox(
                width: 132,
                child: DropdownButtonFormField<StorageLocation>(
                  initialValue: line.location,
                  decoration: InputDecoration(labelText: l10n.locationLabel),
                  items: [
                    for (final loc in StorageLocation.values)
                      DropdownMenuItem(
                        value: loc,
                        child: Text(l10n.location(loc)),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => line.location = v ?? line.location),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
