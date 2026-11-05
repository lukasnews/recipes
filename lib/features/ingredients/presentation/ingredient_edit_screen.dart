import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../household/domain/allergen.dart';
import '../domain/ingredient.dart';
import 'ingredient_picker.dart';
import 'merge.dart';

class IngredientEditScreen extends ConsumerStatefulWidget {
  const IngredientEditScreen({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  ConsumerState<IngredientEditScreen> createState() =>
      _IngredientEditScreenState();
}

class _IngredientEditScreenState extends ConsumerState<IngredientEditScreen> {
  final _name = TextEditingController();
  final _synonyms = TextEditingController();
  Aisle _aisle = Aisle.other;
  BaseUnit _base = BaseUnit.pcs;
  bool _always = false;
  Set<Allergen> _allergens = {};
  final _conversions = <(String, TextEditingController)>[];
  final _density = TextEditingController();
  final _pieceGrams = TextEditingController();
  Ingredient? _original;

  @override
  void dispose() {
    _name.dispose();
    _synonyms.dispose();
    _density.dispose();
    _pieceGrams.dispose();
    for (final (_, c) in _conversions) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Ingredient i) {
    _original = i;
    _name.text = i.name;
    _synonyms.text = i.synonyms.join(', ');
    _aisle = i.aisle;
    _base = i.baseUnit;
    _always = i.alwaysAvailable;
    _allergens = {...i.allergens};
    _density.text = i.density == null
        ? ''
        : formatAmount(i.density!, fractions: false);
    _pieceGrams.text = i.pieceGrams == null
        ? ''
        : formatAmount(i.pieceGrams!, fractions: false);
    for (final e in i.conversions.entries) {
      _conversions.add((
        e.key,
        TextEditingController(text: formatAmount(e.value, fractions: false)),
      ));
    }
  }

  List<String> get _synonymList => _synonyms.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void _prefer(String term) {
    final current = _name.text.trim();
    if (term == current) return;
    setState(() {
      _name.text = term;
      _synonyms.text = [
        if (current.isNotEmpty) current,
        ..._synonymList.where((s) => s.toLowerCase() != term.toLowerCase()),
      ].join(', ');
    });
  }

  static double? _positive(String text) {
    final v = parseUserNumber(text);
    return v != null && v > 0 ? v : null;
  }

  String get _baseLabel => _base == BaseUnit.pcs ? 'Stk.' : _base.name;

  void _save() {
    final original = _original;
    if (original == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final updated = original.copyWith(
      name: name,
      synonyms: _synonymList,
      aisle: _aisle,
      baseUnit: _base,
      alwaysAvailable: _always,
      allergens: _allergens,
      conversions: {
        for (final (unit, c) in _conversions)
          if ((parseUserNumber(c.text) ?? 0) > 0)
            unit: parseUserNumber(c.text)!,
      },
      density: () => _positive(_density.text),
      pieceGrams: () => _positive(_pieceGrams.text),
    );
    fire(ref.read(ingredientRepositoryProvider).save(updated));
    context.pop();
  }

  Future<void> _addConversion() async {
    final used = {for (final (u, _) in _conversions) u, _base.name};
    final options = Units.all
        .map((u) => u.key)
        .where((k) => !used.contains(k))
        .toList();
    final unit = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.unitLabel),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, o),
              child: Text(o),
            ),
        ],
      ),
    );
    if (unit == null) return;
    setState(() => _conversions.add((unit, TextEditingController())));
  }

  Future<void> _mergeInto() async {
    final source = _original;
    if (source == null) return;
    final choice = await pickIngredient(context, excludeIds: [source.id]);
    final target = choice?.ingredient;
    if (target == null || !mounted) return;
    final merged = await confirmMerge(context, ref, source, target);
    if (merged && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ingredient = ref.watch(ingredientsByIdProvider)[widget.ingredientId];
    if (_original == null && ingredient != null) _load(ingredient);
    if (_original == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final usage = (ref.watch(recipesProvider).value ?? const [])
        .where((r) => r.ingredientIds.contains(widget.ingredientId))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_original!.name),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.ingredientName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _synonyms,
            maxLines: null,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.synonymsLabel,
              helperText: l10n.synonymsHint,
              helperMaxLines: 2,
            ),
          ),
          if (_synonymList.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.displayNameLabel, style: theme.textTheme.titleSmall),
            Text(l10n.displayNameHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in [_name.text.trim(), ..._synonymList])
                  if (term.isNotEmpty)
                    ChoiceChip(
                      label: Text(term),
                      selected: term == _name.text.trim(),
                      onSelected: (_) => _prefer(term),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<Aisle>(
            initialValue: _aisle,
            decoration: InputDecoration(labelText: l10n.aisleLabel),
            items: [
              for (final a in Aisle.values)
                DropdownMenuItem(value: a, child: Text(l10n.aisle(a))),
            ],
            onChanged: (v) => setState(() => _aisle = v ?? _aisle),
          ),
          const SizedBox(height: 16),
          Text(l10n.baseUnitLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<BaseUnit>(
            segments: [
              for (final u in BaseUnit.values)
                ButtonSegment(value: u, label: Text(l10n.baseUnit(u))),
            ],
            selected: {_base},
            onSelectionChanged: (s) => setState(() => _base = s.first),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.alwaysAvailableLabel),
            subtitle: Text(l10n.alwaysAvailableHint),
            value: _always,
            onChanged: (v) => setState(() => _always = v),
          ),
          const SizedBox(height: 8),
          Text(l10n.ingredientAllergens, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in Allergen.values)
                FilterChip(
                  label: Text(l10n.allergen(a)),
                  selected: _allergens.contains(a),
                  onSelected: (on) => setState(
                    () => on ? _allergens.add(a) : _allergens.remove(a),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.weightsLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.weightsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: TextField(
                  controller: _density,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.densityLabel,
                    suffixText: 'g/ml',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _pieceGrams,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.pieceGramsLabel,
                    suffixText: 'g',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.conversionsLabel, style: theme.textTheme.titleSmall),
          for (final (i, (unit, controller)) in _conversions.indexed)
            Row(
              children: [
                SizedBox(width: 80, child: Text('1 $unit =')),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(suffixText: _baseLabel),
                  ),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => setState(() {
                    _conversions.removeAt(i).$2.dispose();
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addConversion,
              icon: const Icon(Icons.add),
              label: Text(l10n.addConversion),
            ),
          ),
          const Divider(height: 32),
          Text(l10n.ingredientInUse(usage)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _mergeInto,
            icon: const Icon(Icons.merge_type),
            label: Text(l10n.mergeInto),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              if (usage > 0) {
                showSnack(context, l10n.deleteIngredientBlocked);
                return;
              }
              fire(
                ref
                    .read(ingredientRepositoryProvider)
                    .delete(widget.ingredientId),
              );
              fire(
                ref.read(pantryRepositoryProvider).delete(widget.ingredientId),
              );
              context.pop();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
