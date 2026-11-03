import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/matching/normalize.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_factory.dart';
import 'merge.dart';
import 'preferred_name_sheet.dart';

final duplicatesProvider = Provider<List<(Ingredient, Ingredient)>>((ref) {
  final list = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
  final byId = {for (final i in list) i.id: i};
  return [
    for (final (a, b, _) in IngredientMatcher.findDuplicates(
      list.map((i) => i.candidate).toList(),
    ))
      (byId[a]!, byId[b]!),
  ];
});

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  String _q = '';

  void _create() {
    final repo = ref.read(ingredientRepositoryProvider);
    final name = _q.trim();
    final ing = newIngredient(repo.newId(), name.isEmpty ? '?' : name);
    fire(repo.save(ing));
    context.push(Routes.ingredient(ing.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = ref.watch(ingredientsProvider);
    final duplicates = ref.watch(duplicatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ingredientsManage)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ingredients-fab',
        tooltip: l10n.newIngredient,
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: AsyncView(
        value: value,
        data: (list) {
          final q = foldText(_q);
          final filtered = q.isEmpty
              ? list
              : list
                    .where(
                      (i) => [
                        i.name,
                        ...i.synonyms,
                      ].any((s) => foldText(s).contains(q)),
                    )
                    .toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SearchBar(
                  hintText: l10n.searchIngredients,
                  leading: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              if (duplicates.isNotEmpty && q.isEmpty) ...[
                ListTile(
                  title: Text(
                    l10n.duplicatesTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  subtitle: Text(l10n.duplicatesHint),
                ),
                for (final (a, b) in duplicates)
                  ListTile(
                    leading: const Icon(Icons.merge_type),
                    title: Text('${a.name}  ↔  ${b.name}'),
                    trailing: TextButton(
                      onPressed: () => confirmMerge(context, ref, b, a),
                      child: Text(l10n.mergeAction),
                    ),
                  ),
                const Divider(),
              ],
              for (final i in filtered)
                ListTile(
                  title: Text(i.name),
                  subtitle: Text(
                    [l10n.aisle(i.aisle), ...i.synonyms].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: i.synonyms.isEmpty
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: l10n.choosePreferredName,
                          onPressed: () =>
                              showPreferredNameSheet(context, ref, i),
                          icon: const Icon(Icons.swap_horiz),
                        ),
                  onTap: () => context.push(Routes.ingredient(i.id)),
                  onLongPress: i.synonyms.isEmpty
                      ? null
                      : () => showPreferredNameSheet(context, ref, i),
                ),
            ],
          );
        },
      ),
    );
  }
}
