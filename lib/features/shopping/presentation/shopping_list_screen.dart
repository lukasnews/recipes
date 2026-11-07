import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/display_units.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../ingredients/domain/ingredient.dart';
import '../domain/pack_sizes.dart';
import '../domain/shopping_item.dart';
import '../domain/stores.dart';
import 'pantry_transfer_sheet.dart';
import 'share_list_sheet.dart';
import 'shopping_add.dart';
import 'shopping_scan_sheet.dart';
import 'store_sheet.dart';

/// "1500 g" -> "1,5 kg", "2 Stk." -> "2", "½ TL" stays.
String shoppingQuantity(
  ShoppingItem item, [
  UnitDisplay display = UnitDisplay.original,
]) {
  final a = item.amount;
  if (a == null) return '';
  if (display != UnitDisplay.original && item.unit != 'Stk.') {
    return displayQuantity(a, item.unit, display);
  }
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

/// Open items as plain text for messengers, grouped by aisle:
/// "Einkaufsliste\n\nObst & Gemüse\n- 6 Paradeiser\n…".
String shoppingShareText(
  List<ShoppingItem> items,
  Map<String, Ingredient> ingredients, {
  required String title,
  required String Function(Aisle) aisleName,
  UnitDisplay display = UnitDisplay.original,
  List<Aisle> order = Aisle.values,
  ({List<String> stores, String anywhere})? byStore,
}) {
  final open = items.where((i) => !i.checked).toList();
  final sections = <(String, List<ShoppingItem>)>[];
  if (byStore != null) {
    for (final (store, list) in groupByStore(
      open,
      ingredients,
      byStore.stores,
      order,
    )) {
      sections.add((store ?? byStore.anywhere, list));
    }
  } else {
    final byAisle = <Aisle, List<ShoppingItem>>{};
    for (final i in open) {
      byAisle.putIfAbsent(i.aisle, () => []).add(i);
    }
    for (final aisle in order) {
      if (byAisle[aisle] case final list?) {
        sections.add((aisleName(aisle), list));
      }
    }
  }
  final out = StringBuffer(title);
  for (final (heading, list) in sections) {
    out.write('\n\n$heading');
    for (final i in list) {
      final line = [
        shoppingQuantity(i, display),
        ingredients[i.ingredientId]?.name ?? i.text,
      ].where((s) => s.isNotEmpty).join(' ');
      out.write('\n- $line');
    }
  }
  return out.toString();
}

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _input = TextEditingController();

  /// "Nur Hofer" while shopping there (null = all).
  String? _only;
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
    addShoppingLine(ref, text);
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
          IconButton(
            tooltip: l10n.shareShoppingList,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => showShareListSheet(context, ref, items),
          ),
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
                prefixIcon: IconButton(
                  tooltip: l10n.scanListTooltip,
                  onPressed: () => scanShoppingList(context, ref),
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
                suffixIcon: IconButton(
                  tooltip: l10n.add,
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
                  : _ShoppingList(
                      items: items,
                      only: _only,
                      onOnly: (s) => setState(() => _only = s),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingList extends ConsumerWidget {
  const _ShoppingList({
    required this.items,
    required this.only,
    required this.onOnly,
  });

  final List<ShoppingItem> items;
  final String? only;
  final ValueChanged<String?> onOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ingredients = ref.watch(ingredientsByIdProvider);
    final stores = ref.watch(storesProvider);
    final byStore = ref.watch(shoppingByStoreProvider);
    final allOpen = items.where((i) => !i.checked).toList();
    // Shops that matter for the open items, in the household's order.
    final used = {
      for (final i in allOpen) ...itemStores(i, ingredients[i.ingredientId]),
    };
    final storeChips = [
      ...stores.where(used.contains),
      ...used.where((s) => !stores.contains(s)),
    ];
    final current = storeChips.contains(only) ? only : null;
    final open = allOpen
        .where((i) => availableAt(i, ingredients[i.ingredientId], current))
        .toList();
    final done = items.where((i) => i.checked).toList();
    final byAisle = <Aisle, List<ShoppingItem>>{};
    for (final i in open) {
      byAisle.putIfAbsent(i.aisle, () => []).add(i);
    }
    final uid = ref.read(authUserProvider).value?.uid;
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            spacing: 8,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.category_outlined),
                    tooltip: l10n.shoppingByAisle,
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.storefront_outlined),
                    tooltip: l10n.shoppingByStore,
                  ),
                ],
                selected: {byStore},
                onSelectionChanged: (s) {
                  if (uid == null) return;
                  fire(
                    ref
                        .read(householdRepositoryProvider)
                        .setShoppingByStore(uid, on: s.first),
                  );
                },
              ),
              for (final s in storeChips)
                FilterChip(
                  label: Text(l10n.storeOnly(s)),
                  selected: current == s,
                  onSelected: (on) => onOnly(on ? s : null),
                ),
              if (current != null)
                if (flyerLink(current, ref.watch(storeLinksProvider))
                    case final link?)
                  ActionChip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text(l10n.storeFlyer),
                    onPressed: () =>
                        fire(ref.read(urlOpenerProvider).open(link)),
                  ),
            ],
          ),
        ),
        if (byStore)
          for (final (store, list) in groupByStore(
            open,
            ingredients,
            stores,
            ref.watch(aisleOrderProvider),
          )) ...[
            Row(
              children: [
                Expanded(child: header(store ?? l10n.storeAnywhere)),
                if (store != null)
                  if (flyerLink(store, ref.watch(storeLinksProvider))
                      case final link?)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 12),
                      child: TextButton.icon(
                        onPressed: () =>
                            fire(ref.read(urlOpenerProvider).open(link)),
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(l10n.storeFlyer),
                      ),
                    ),
              ],
            ),
            for (final item in list) _ItemTile(item: item, section: store),
          ]
        else
          for (final aisle in ref.watch(aisleOrderProvider))
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
  const _ItemTile({required this.item, this.section});

  final ShoppingItem item;

  /// Shop section the tile is shown under (list by shop).
  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shoppingRepositoryProvider);
    final qty = shoppingQuantity(item, ref.watch(unitDisplayProvider));
    // Linked items follow renames of the ingredient (e.g. preferred name).
    final ing = ref.watch(ingredientsByIdProvider)[item.ingredientId];
    final name = ing?.name ?? item.text;
    final l10n = context.l10n;
    final pack = shoppingPackHint(item, ing, l10n.packLabel);
    final at = itemStores(item, ing);
    final where = item.checked || at.isEmpty
        ? null
        : item.store != null
        ? (section == null ? l10n.storeFixed(item.store!) : null)
        : section == null
        ? at.join(', ')
        : (at.length > 1
              ? l10n.storeAlso(at.where((s) => s != section).join(', '))
              : null);
    final subtitle = [?pack, ?where].join(' · ');
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
      child: GestureDetector(
        onLongPress: () => showStoreSheet(context, item),
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
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
        ),
      ),
    );
  }
}
