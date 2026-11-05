import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../ingredients/domain/ingredient.dart';
import '../domain/inventory.dart';
import '../domain/pantry_item.dart';
import 'stock_actions.dart';

/// Vorrat → Inventur: swipe through every item (by storage place), confirm
/// or correct the amount, apply everything at the end.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _pages = PageController();

  /// Stock when the inventory started; changes are applied against it.
  late final Map<String, PantryItem> _start = {
    ...?ref.read(pantryProvider).value,
  };
  late final List<(PantryItem, Ingredient)> _items = () {
    final byId = ref.read(ingredientsByIdProvider);
    return [
      for (final item in _start.values)
        if (byId[item.ingredientId] case final ing?) (item, ing),
    ]..sort((a, b) {
      final l = a.$1.location.index.compareTo(b.$1.location.index);
      return l != 0 ? l : a.$2.name.compareTo(b.$2.name);
    });
  }();
  final _counted = <String, double>{};
  late final _fields = [
    for (final (item, _) in _items)
      TextEditingController(text: formatAmount(item.amount, fractions: false)),
  ];
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _count(int i, double amount) {
    setState(() => _counted[_items[i].$1.ingredientId] = amount);
    _next();
  }

  void _apply() {
    final deltas = inventoryDeltas(_counted, _start);
    final repo = ref.read(pantryRepositoryProvider);
    for (final e in deltas.entries) {
      fire(repo.changeAmount(e.key, e.value));
    }
    checkMinStock(context, ref, {
      for (final e in deltas.entries)
        if (e.value < 0) e.key: _counted[e.key]!,
    });
    showSnack(context, context.l10n.inventoryDone(deltas.length));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final changed = inventoryDeltas(_counted, _start).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryTitle),
        actions: [
          TextButton(
            onPressed: _apply,
            child: Text(l10n.inventoryApply(changed)),
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(child: Text(l10n.pantryEmpty))
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_page + 1) / (_items.length + 1),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _items.length + 1,
                    onPageChanged: (p) => setState(() => _page = p),
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 16,
                              children: [
                                const Icon(Icons.fact_check_outlined, size: 56),
                                Text(
                                  l10n.inventorySummary(
                                    _counted.length,
                                    _items.length,
                                    changed,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium,
                                ),
                                FilledButton(
                                  onPressed: _apply,
                                  child: Text(l10n.inventoryApply(changed)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final (item, ing) = _items[i];
                      final unit = ing.baseUnit == BaseUnit.pcs
                          ? 'Stk.'
                          : ing.baseUnit.name;
                      final counted = _counted[item.ingredientId];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            Text(
                              l10n.inventoryOf(i + 1, _items.length),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              ing.name,
                              style: theme.textTheme.headlineMedium,
                            ),
                            Text(
                              '${l10n.location(item.location)} · '
                              '${l10n.inventoryWas(formatBaseAmount(item.amount, ing.baseUnit))}',
                              style: theme.textTheme.bodyLarge,
                            ),
                            TextField(
                              controller: _fields[i],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: theme.textTheme.headlineSmall,
                              decoration: InputDecoration(
                                labelText: l10n.inventoryNow,
                                suffixText: unit,
                              ),
                              onSubmitted: (t) =>
                                  _count(i, parseUserNumber(t) ?? item.amount),
                            ),
                            if (counted != null)
                              Text(
                                l10n.inventoryCounted(
                                  formatBaseAmount(counted, ing.baseUnit),
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: () => _count(
                                i,
                                (parseUserNumber(_fields[i].text) ??
                                        item.amount)
                                    .clamp(0, double.infinity)
                                    .toDouble(),
                              ),
                              icon: const Icon(Icons.check),
                              label: Text(l10n.inventoryConfirm),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _fields[i].text = '0';
                                _count(i, 0);
                              },
                              icon: const Icon(Icons.remove_shopping_cart),
                              label: Text(l10n.inventoryEmpty),
                            ),
                            TextButton(
                              onPressed: _next,
                              child: Text(l10n.inventorySkip),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
