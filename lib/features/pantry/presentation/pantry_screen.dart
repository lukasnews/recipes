import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/profile_button.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/ingredient_factory.dart';
import '../../ingredients/presentation/ingredient_picker.dart';
import '../domain/pantry_item.dart';
import 'stock_actions.dart';

String baseLabel(BaseUnit u) => u == BaseUnit.pcs ? 'Stk.' : u.name;

/// Step for the quick +/- buttons.
double stockStep(BaseUnit base, double amount) {
  if (base == BaseUnit.pcs) return 1;
  if (amount >= 1000) return 250;
  if (amount >= 200) return 100;
  return 10;
}

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = ref.watch(pantryProvider);
    final ingredients = ref.watch(ingredientsByIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPantry),
        actions: const [ProfileButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pantry-fab',
        onPressed: () => showAddToPantrySheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addToPantry),
      ),
      body: AsyncView(
        value: value,
        data: (pantry) {
          final items =
              pantry.values
                  .where((p) => ingredients.containsKey(p.ingredientId))
                  .toList()
                ..sort(
                  (a, b) =>
                      ingredients[a.ingredientId]!.name.toLowerCase().compareTo(
                        ingredients[b.ingredientId]!.name.toLowerCase(),
                      ),
                );
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.kitchen_outlined,
              message: '${l10n.pantryEmpty}\n${l10n.pantryEmptyHint}',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final loc in StorageLocation.values)
                if (items.any((i) => i.location == loc)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      l10n.location(loc),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final item in items.where((i) => i.location == loc))
                    _PantryTile(
                      item: item,
                      ingredient: ingredients[item.ingredientId]!,
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PantryTile extends ConsumerWidget {
  const _PantryTile({required this.item, required this.ingredient});

  final PantryItem item;
  final Ingredient ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final step = stockStep(ingredient.baseUnit, item.amount);
    return ListTile(
      title: Text(ingredient.name),
      subtitle: Text(
        [
          formatBaseAmount(item.amount, ingredient.baseUnit),
          if (item.isBelowMin) l10n.belowMin,
        ].join(' · '),
        style: item.isBelowMin
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      onTap: () => _showEditSheet(context, item, ingredient),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: item.amount > 0
                ? () => adjustStock(context, ref, ingredient, -step)
                : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => adjustStock(context, ref, ingredient, step),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditSheet(
  BuildContext context,
  PantryItem item,
  Ingredient ingredient,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _EditSheet(item: item, ingredient: ingredient),
);

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.item, required this.ingredient});

  final PantryItem item;
  final Ingredient ingredient;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _amount = TextEditingController(
    text: formatAmount(widget.item.amount, fractions: false),
  );
  late final _min = TextEditingController(
    text: widget.item.minAmount == null
        ? ''
        : formatAmount(widget.item.minAmount!, fractions: false),
  );
  late StorageLocation _location = widget.item.location;

  @override
  void dispose() {
    _amount.dispose();
    _min.dispose();
    super.dispose();
  }

  void _save() {
    final repo = ref.read(pantryRepositoryProvider);
    final newAmount = parseUserNumber(_amount.text);
    if (newAmount != null && newAmount >= 0) {
      final delta = newAmount - widget.item.amount;
      if (delta != 0) {
        fire(repo.changeAmount(widget.item.ingredientId, delta));
      }
    }
    final min = parseUserNumber(_min.text);
    fire(
      repo.update(
        widget.item.ingredientId,
        location: _location,
        minAmount: () => min,
      ),
    );
    if (newAmount != null) {
      checkMinStock(context, ref, {widget.item.ingredientId: newAmount});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = baseLabel(widget.ingredient.baseUnit);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.ingredient.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amountLabel,
              suffixText: unit,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _min,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.minAmountLabel,
              helperText: l10n.minAmountHint,
              suffixText: unit,
            ),
          ),
          const SizedBox(height: 12),
          _LocationPicker(
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
          TextButton(
            onPressed: () {
              fire(
                ref
                    .read(pantryRepositoryProvider)
                    .delete(widget.item.ingredientId),
              );
              Navigator.pop(context);
            },
            child: Text(l10n.removeFromPantry),
          ),
        ],
      ),
    );
  }
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({required this.value, required this.onChanged});

  final StorageLocation value;
  final ValueChanged<StorageLocation> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<StorageLocation>(
      segments: [
        for (final l in StorageLocation.values)
          ButtonSegment(value: l, label: Text(l10n.location(l))),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

Future<void> showAddToPantrySheet(BuildContext context) async {
  final choice = await pickIngredient(context);
  if (choice == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddSheet(choice: choice),
  );
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({required this.choice});

  final IngredientChoice choice;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  final _amount = TextEditingController();
  late String _unit;
  StorageLocation _location = StorageLocation.pantry;

  Ingredient? get _existing => widget.choice.ingredient;

  List<String> get _units {
    final ing = _existing;
    if (ing == null) return const ['g', 'kg', 'ml', 'l', 'Stk.'];
    final generic = switch (ing.baseUnit) {
      BaseUnit.g => const ['g', 'kg', 'dag'],
      BaseUnit.ml => const ['ml', 'l', 'dl'],
      BaseUnit.pcs => const ['Stk.'],
    };
    return {...generic, ...ing.conversions.keys}.toList();
  }

  @override
  void initState() {
    super.initState();
    _unit = _units.first;
    final existing = _existing;
    if (existing != null) {
      _location =
          ref.read(pantryProvider).value?[existing.id]?.location ??
          switch (existing.aisle) {
            Aisle.dairy || Aisle.meat => StorageLocation.fridge,
            Aisle.frozen => StorageLocation.freezer,
            _ => StorageLocation.pantry,
          };
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseUserNumber(_amount.text);
    if (amount == null || amount <= 0) return;
    var ing = _existing;
    if (ing == null) {
      final repo = ref.read(ingredientRepositoryProvider);
      ing = newIngredient(repo.newId(), widget.choice.newName!, unit: _unit);
      fire(repo.save(ing));
    }
    var base = ing.toBase(amount, _unit == 'Stk.' ? null : _unit);
    if (base == null) {
      final factor = await askConversion(context, ref, ing, _unit);
      if (factor == null) return;
      base = amount * factor;
    }
    fire(
      ref
          .read(pantryRepositoryProvider)
          .changeAmount(ing.id, base, location: _location),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _existing?.name ?? widget.choice.newName ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
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
                ),
              ),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
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
          const SizedBox(height: 12),
          _LocationPicker(
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l10n.addToPantry)),
        ],
      ),
    );
  }
}
