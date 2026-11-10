import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../recipes/domain/categories.dart';
import '../../recipes/domain/recipe.dart';

/// Einstellungen → "Kategorien": own categories (add, rename, delete),
/// built-in ones shown or hidden, order by dragging (= order of the chips).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  /// Name for a new or renamed category; null when cancelled, empty or
  /// already taken (as name or as shown label of another category).
  Future<String?> _askName(
    BuildContext context,
    WidgetRef ref, {
    String initial = '',
    required String title,
  }) async {
    final l10n = context.l10n;
    final name = (await showTextInputDialog(
      context,
      title: title,
      label: l10n.customCategoryLabel,
      initial: initial,
      capitalization: TextCapitalization.sentences,
    ))?.trim();
    if (name == null || name.isEmpty || name == initial) return null;
    final taken = {
      for (final c in ref.read(categoriesProvider)) ...[
        c.toLowerCase(),
        l10n.category(c).toLowerCase(),
      ],
      'getränke',
      'getraenke',
    };
    if (taken.contains(name.toLowerCase())) {
      if (context.mounted) showSnack(context, l10n.categoryExists(name));
      return null;
    }
    return name;
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final hid = ref.read(householdIdProvider);
    final name = await _askName(context, ref, title: context.l10n.categoryNew);
    if (name == null || hid == null) return;
    fire(
      ref.read(householdRepositoryProvider).setCategoryOrder(hid, [
        ...ref.read(categoriesProvider),
        name,
      ]),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String old) async {
    final hid = ref.read(householdIdProvider);
    final name = await _askName(
      context,
      ref,
      initial: old,
      title: context.l10n.categoryRename,
    );
    if (name == null || hid == null) return;
    final order = [
      for (final c in ref.read(categoriesProvider)) c == old ? name : c,
    ];
    fire(
      ref
          .read(householdRepositoryProvider)
          .moveCategory(
            hid,
            recipeIds: _recipesIn(ref, old),
            to: name,
            order: order,
          ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String c) async {
    final l10n = context.l10n;
    final hid = ref.read(householdIdProvider);
    final ids = _recipesIn(ref, c);
    final ok = await confirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: ids.isEmpty
          ? l10n.categoryDeleteEmpty(c)
          : l10n.categoryDeleteMove(
              c,
              ids.length,
              l10n.category(RecipeCategories.cooking),
            ),
      confirmLabel: l10n.delete,
    );
    if (!ok || hid == null) return;
    fire(
      ref
          .read(householdRepositoryProvider)
          .moveCategory(
            hid,
            recipeIds: ids,
            to: RecipeCategories.cooking,
            order: [
              for (final x in ref.read(categoriesProvider))
                if (x != c) x,
            ],
          ),
    );
  }

  List<String> _recipesIn(WidgetRef ref, String category) => [
    for (final r in ref.read(recipesProvider).value ?? const <Recipe>[])
      if (r.category == category) r.id,
  ];

  void _toggleHidden(WidgetRef ref, String c, Set<String> hidden) {
    final hid = ref.read(householdIdProvider);
    if (hid == null) return;
    final next = {...hidden};
    if (!next.remove(c)) next.add(c);
    fire(ref.read(householdRepositoryProvider).setHiddenCategories(hid, next));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = ref.watch(categoriesProvider);
    final hidden = ref.watch(hiddenCategoriesProvider);
    final counts = categoryCounts(ref.watch(recipesProvider).value ?? const []);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.categoryNew),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.categoriesHint),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 96),
              onReorderItem: (from, to) {
                final hid = ref.read(householdIdProvider);
                if (hid == null) return;
                final next = [...all];
                next.insert(to, next.removeAt(from));
                fire(
                  ref
                      .read(householdRepositoryProvider)
                      .setCategoryOrder(hid, next),
                );
              },
              children: [
                for (final (i, c) in all.indexed)
                  _CategoryTile(
                    key: ValueKey(c),
                    index: i,
                    label: l10n.category(c),
                    count: counts[c] ?? 0,
                    builtIn: RecipeCategories.builtIn.contains(c),
                    hidden: hidden.contains(c),
                    canHide: c != RecipeCategories.cooking,
                    onToggleHidden: () => _toggleHidden(ref, c, hidden),
                    onRename: () => _rename(context, ref, c),
                    onDelete: () => _delete(context, ref, c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.index,
    required this.label,
    required this.count,
    required this.builtIn,
    required this.hidden,
    required this.canHide,
    required this.onToggleHidden,
    required this.onRename,
    required this.onDelete,
  });

  final int index;
  final String label;
  final int count;
  final bool builtIn;
  final bool hidden;
  final bool canHide;
  final VoidCallback onToggleHidden;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        builtIn ? Icons.category_outlined : Icons.label_outline,
        color: hidden ? scheme.outline : null,
      ),
      title: Text(
        label,
        style: hidden ? TextStyle(color: scheme.outline) : null,
      ),
      subtitle: Text(
        [
          l10n.recipeCount(count),
          if (hidden) l10n.categoryHidden,
          if (builtIn) l10n.categoryBuiltIn,
        ].join(' · '),
      ),
      onTap: builtIn ? null : onRename,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (builtIn && canHide)
            IconButton(
              tooltip: hidden ? l10n.categoryShow : l10n.categoryHide,
              onPressed: onToggleHidden,
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          if (!builtIn)
            IconButton(
              tooltip: l10n.delete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, semanticLabel: l10n.aisleOrderDrag),
          ),
        ],
      ),
    );
  }
}
