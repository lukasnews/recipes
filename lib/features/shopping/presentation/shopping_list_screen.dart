import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/ingredient_line_parser.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../ingredients/domain/ingredient.dart';
import '../domain/shopping_item.dart';
import 'pantry_transfer_sheet.dart';

/// "1500 g" -> "1,5 kg", "2 Stk." -> "2", "½ TL" stays.
String shoppingQuantity(ShoppingItem item) {
  final a = item.amount;
  if (a == null) return '';
  switch (item.unit) {
    case 'g':
      return formatBaseAmount(a, BaseUnit.g);
    case 'ml':
      return formatBaseAmount(a, BaseUnit.ml);
    case 'Stk.':
      return formatAmount(a);
    default:
      return formatWithUnit(a, item.unit);
  }
}

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final parsed = parseIngredientLine(text);
    final match = ref.read(ingredientMatcherProvider).match(parsed.name);
    // Only link on a certain match; free text like "Spülmittel" stays as is.
    final ing = match.isMatch && !match.isUncertain
        ? ref.read(ingredientsByIdProvider)[match.id]
        : null;
    fire(
      ref
          .read(shoppingRepositoryProvider)
          .add(
            text: ing?.name ?? parsed.name,
            current: ref.read(shoppingProvider).value ?? const [],
            ingredientId: ing?.id,
            amount: parsed.amount,
            unit: parsed.unit ?? (parsed.amount != null ? 'Stk.' : null),
            aisle: ing?.aisle ?? Aisle.other,
          ),
    );
    _input.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = ref.watch(shoppingProvider);
    final repo = ref.watch(shoppingRepositoryProvider);
    final items = value.value ?? const <ShoppingItem>[];
    final checked = items.where((i) => i.checked).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navShopping),
        actions: [
          PopupMenuButton<void>(
            enabled: checked.isNotEmpty,
            icon: const Icon(Icons.playlist_remove),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => showPantryTransferSheet(context, items),
                child: Text(l10n.moveCheckedToPantry),
              ),
              PopupMenuItem(
                onTap: () => fire(repo.deleteAll(checked.map((i) => i.id))),
                child: Text(l10n.removeChecked),
              ),
            ],
          ),
          const ProfileButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.shoppingAddHint,
                filled: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          Expanded(
            child: AsyncView(
              value: value,
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      message: l10n.shoppingEmpty,
                    )
                  : _ShoppingList(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingList extends ConsumerWidget {
  const _ShoppingList({required this.items});

  final List<ShoppingItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = items.where((i) => !i.checked).toList();
    final done = items.where((i) => i.checked).toList();
    final byAisle = <Aisle, List<ShoppingItem>>{};
    for (final i in open) {
      byAisle.putIfAbsent(i.aisle, () => []).add(i);
    }
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final aisle in Aisle.values)
          if (byAisle[aisle] != null) ...[
            header(l10n.aisle(aisle)),
            for (final item in byAisle[aisle]!) _ItemTile(item: item),
          ],
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.checkedSection,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showPantryTransferSheet(context, items),
                  icon: const Icon(Icons.kitchen_outlined),
                  label: Text(l10n.moveCheckedToPantry),
                ),
              ],
            ),
          ),
          for (final item in done) _ItemTile(item: item),
        ],
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shoppingRepositoryProvider);
    final qty = shoppingQuantity(item);
    // Linked items follow renames of the ingredient (e.g. preferred name).
    final name =
        ref.watch(ingredientsByIdProvider)[item.ingredientId]?.name ??
        item.text;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => fire(repo.delete(item.id)),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: item.checked,
        onChanged: (v) => fire(repo.setChecked(item.id, v ?? false)),
        title: Text(
          [if (qty.isNotEmpty) qty, name].join(' '),
          style: item.checked
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
      ),
    );
  }
}
