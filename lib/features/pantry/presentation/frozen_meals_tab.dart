import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/frozen_meal.dart';

final _dateFormat = DateFormat('d. M. yyyy', 'de');

/// Cooked dishes in the freezer, oldest first.
class FrozenMealsTab extends ConsumerWidget {
  const FrozenMealsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'frozen-fab',
        onPressed: () => showFrozenMealSheet(context),
        icon: const Icon(Icons.ac_unit),
        label: Text(l10n.freezeMeal),
      ),
      body: AsyncView(
        value: ref.watch(frozenMealsProvider),
        data: (meals) => meals.isEmpty
            ? EmptyState(
                icon: Icons.ac_unit,
                message:
                    '${l10n.frozenMealsEmpty}\n${l10n.frozenMealsEmptyHint}',
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final m in meals)
                    ListTile(
                      title: Text(m.title),
                      subtitle: Text(
                        [
                          l10n.frozenPortions(m.portions),
                          l10n.frozenSince(_dateFormat.format(m.frozenOn)),
                          if (m.isOld(now)) l10n.frozenOld,
                        ].join(' · '),
                        style: m.isOld(now)
                            ? TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              )
                            : null,
                      ),
                      onTap: () => showFrozenMealSheet(context, meal: m),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => fire(
                              ref
                                  .read(frozenMealRepositoryProvider)
                                  .changePortions(m, -1),
                            ),
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => fire(
                              ref
                                  .read(frozenMealRepositoryProvider)
                                  .changePortions(m, 1),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Add (meal == null) or edit a frozen meal.
Future<void> showFrozenMealSheet(BuildContext context, {FrozenMeal? meal}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MealSheet(meal: meal),
    );

class _MealSheet extends ConsumerStatefulWidget {
  const _MealSheet({this.meal});

  final FrozenMeal? meal;

  @override
  ConsumerState<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<_MealSheet> {
  late final _title = TextEditingController(text: widget.meal?.title ?? '');
  late final _portions = TextEditingController(
    text: '${widget.meal?.portions ?? 2}',
  );
  late final _note = TextEditingController(text: widget.meal?.note ?? '');
  late DateTime _date = widget.meal?.frozenOn ?? DateTime.now();
  String? _recipeId;

  @override
  void initState() {
    super.initState();
    _recipeId = widget.meal?.recipeId;
  }

  @override
  void dispose() {
    _title.dispose();
    _portions.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickRecipe() async {
    final recipes = ref.read(recipesProvider).value ?? const <Recipe>[];
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        children: [
          for (final r in recipes)
            ListTile(
              title: Text(r.title),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      _title.text = picked.title;
      _recipeId = picked.id;
    });
  }

  void _save() {
    final title = _title.text.trim();
    final portions = int.tryParse(_portions.text.trim()) ?? 0;
    if (title.isEmpty || portions <= 0) return;
    final repo = ref.read(frozenMealRepositoryProvider);
    final meal = widget.meal;
    if (meal == null) {
      fire(
        repo.add(
          title: title,
          portions: portions,
          recipeId: _recipeId,
          frozenOn: _date,
          note: _note.text.trim(),
        ),
      );
    } else {
      fire(
        repo.update(
          meal.id,
          title: title,
          portions: portions,
          frozenOn: _date,
          note: _note.text.trim(),
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meal = widget.meal;
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
            meal?.title ?? l10n.freezeMeal,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.mealTitleLabel,
              suffixIcon: IconButton(
                tooltip: l10n.fromRecipe,
                onPressed: _pickRecipe,
                icon: const Icon(Icons.menu_book_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: TextField(
                  controller: _portions,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.portionsLabel),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(_dateFormat.format(_date)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.notesLabel),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
          if (meal != null)
            TextButton(
              onPressed: () {
                fire(ref.read(frozenMealRepositoryProvider).delete(meal.id));
                Navigator.pop(context);
                showSnack(context, l10n.delete);
              },
              child: Text(l10n.delete),
            ),
        ],
      ),
    );
  }
}
