import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/matching/normalize.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/ingredient.dart';

/// Result of [pickIngredient]: an existing ingredient, a name for a new one,
/// or [unlink] to keep the line without an ingredient.
class IngredientChoice {
  const IngredientChoice.existing(Ingredient this.ingredient)
    : newName = null,
      unlink = false;
  const IngredientChoice.create(String this.newName)
    : ingredient = null,
      unlink = false;
  const IngredientChoice.none()
    : ingredient = null,
      newName = null,
      unlink = true;

  final Ingredient? ingredient;
  final String? newName;
  final bool unlink;
}

Future<IngredientChoice?> pickIngredient(
  BuildContext context, {
  String initialQuery = '',
  bool allowUnlink = false,
  Iterable<String> excludeIds = const [],
}) => showModalBottomSheet<IngredientChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _PickerSheet(
    initialQuery: initialQuery,
    allowUnlink: allowUnlink,
    excludeIds: excludeIds.toSet(),
  ),
);

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({
    required this.initialQuery,
    required this.allowUnlink,
    required this.excludeIds,
  });

  final String initialQuery;
  final bool allowUnlink;
  final Set<String> excludeIds;

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create(String name) async {
    final choice = await confirmNewIngredient(
      context,
      ref,
      name,
      excludeIds: widget.excludeIds,
    );
    if (choice != null && mounted) Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final q = foldText(_query.text);
    final matcher = ref.watch(ingredientMatcherProvider);
    final best = q.isEmpty ? null : matcher.match(_query.text).id;
    final filtered =
        all.where((i) {
          if (widget.excludeIds.contains(i.id)) return false;
          if (q.isEmpty) return true;
          return [i.name, ...i.synonyms].any((s) => foldText(s).contains(q)) ||
              i.id == best;
        }).toList()..sort((a, b) {
          if (a.id == best) return -1;
          if (b.id == best) return 1;
          return 0;
        });
    final exactExists = all.any(
      (i) => i.name.toLowerCase() == _query.text.trim().toLowerCase(),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchIngredients,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (_query.text.trim().isNotEmpty && !exactExists)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(
                        l10n.createIngredientNamed(_query.text.trim()),
                      ),
                      onTap: () => _create(_query.text.trim()),
                    ),
                  if (widget.allowUnlink)
                    ListTile(
                      leading: const Icon(Icons.link_off),
                      title: Text(l10n.noIngredientLink),
                      onTap: () =>
                          Navigator.pop(context, const IngredientChoice.none()),
                    ),
                  for (final i in filtered.take(100))
                    ListTile(
                      title: Text(i.name),
                      subtitle: i.synonyms.isEmpty
                          ? null
                          : Text(
                              i.synonyms.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: Text(l10n.aisle(i.aisle)),
                      onTap: () =>
                          Navigator.pop(context, IngredientChoice.existing(i)),
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

/// Before creating "[name]": if similar ingredients exist ("Sahne" vs
/// "Schlagobers"), offers them. Returns the existing one, a create choice,
/// or null when cancelled.
Future<IngredientChoice?> confirmNewIngredient(
  BuildContext context,
  WidgetRef ref,
  String name, {
  Set<String> excludeIds = const {},
}) async {
  final byId = ref.read(ingredientsByIdProvider);
  final similar = [
    for (final id in ref.read(ingredientMatcherProvider).similar(name))
      if (byId[id] != null && !excludeIds.contains(id)) byId[id]!,
  ];
  if (similar.isEmpty) return IngredientChoice.create(name);
  final l10n = context.l10n;
  return showDialog<IngredientChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.similarIngredientsTitle),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.similarIngredientsHint(name)),
        ),
        for (final i in similar)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.useExisting(i.name)),
            subtitle: i.synonyms.isEmpty
                ? null
                : Text(
                    i.synonyms.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => Navigator.pop(context, IngredientChoice.existing(i)),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.add),
          title: Text(l10n.createAnyway(name)),
          onTap: () => Navigator.pop(context, IngredientChoice.create(name)),
        ),
      ],
    ),
  );
}
