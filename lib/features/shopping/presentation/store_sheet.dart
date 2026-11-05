import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../settings/presentation/stores_screen.dart';
import '../domain/shopping_item.dart';

/// Long press on a shopping item: where to buy it this time, and (for
/// linked items) where the ingredient is usually bought.
Future<void> showStoreSheet(BuildContext context, ShoppingItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StoreSheet(item: item),
    );

class _StoreSheet extends ConsumerStatefulWidget {
  const _StoreSheet({required this.item});

  final ShoppingItem item;

  @override
  ConsumerState<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends ConsumerState<_StoreSheet> {
  late String? _store = widget.item.store;
  late final Set<String> _usual = {
    ...?ref.read(ingredientsByIdProvider)[widget.item.ingredientId]?.stores,
  };
  late final List<String> _stores = [
    ...ref.read(storesProvider),
    // Shops used before but removed from the list stay selectable.
    for (final s in {?widget.item.store, ..._usual})
      if (!ref.read(storesProvider).contains(s)) s,
  ];

  Future<void> _addStore() async {
    final name = await askStoreName(context);
    if (name == null || !mounted || _stores.contains(name)) return;
    final hid = ref.read(householdIdProvider);
    if (hid != null) {
      fire(
        ref.read(householdRepositoryProvider).setStores(hid, [
          ...ref.read(storesProvider),
          name,
        ]),
      );
    }
    setState(() => _stores.add(name));
  }

  void _save() {
    final item = widget.item;
    if (_store != item.store) {
      fire(ref.read(shoppingRepositoryProvider).setStore(item.id, _store));
    }
    final ing = ref.read(ingredientsByIdProvider)[item.ingredientId];
    if (ing != null && _usual.toSet() != ing.stores.toSet()) {
      fire(
        ref.read(ingredientRepositoryProvider).setStores(ing.id, [
          for (final s in _stores)
            if (_usual.contains(s)) s,
        ]),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ing = ref.watch(ingredientsByIdProvider)[widget.item.ingredientId];
    final name = ing?.name ?? widget.item.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(name, style: theme.textTheme.titleLarge),
          subtitle: Text(l10n.storeSheetHint),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.storeThisTime,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              RadioGroup<String?>(
                groupValue: _store,
                onChanged: (v) => setState(() => _store = v),
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      title: Text(
                        _usual.isEmpty
                            ? l10n.storeAnywhere
                            : l10n.storeAsUsual(
                                _stores.where(_usual.contains).join(', '),
                              ),
                      ),
                    ),
                    for (final s in _stores)
                      RadioListTile<String?>(value: s, title: Text(s)),
                  ],
                ),
              ),
              if (ing != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    l10n.storeUsually(ing.name),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final s in _stores)
                      FilterChip(
                        label: Text(s),
                        selected: _usual.contains(s),
                        onSelected: (on) => setState(
                          () => on ? _usual.add(s) : _usual.remove(s),
                        ),
                      ),
                  ],
                ).paddingAll(),
              ],
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.storeNew),
                onTap: _addStore,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: FilledButton(onPressed: _save, child: Text(l10n.save)),
        ),
      ],
    );
  }
}

extension on Widget {
  Widget paddingAll() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: this,
  );
}
