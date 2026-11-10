import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/menu.dart';

/// Menus for guests: several recipes, one shopping trip, a timetable.
class MenusScreen extends ConsumerWidget {
  const MenusScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final title = (await showTextInputDialog(
      context,
      title: l10n.menuNew,
      label: l10n.menuTitleLabel,
      hint: l10n.menuTitleHint,
      capitalization: TextCapitalization.sentences,
      confirmLabel: l10n.menuCreate,
    ))?.trim();
    if (title == null || title.isEmpty || !context.mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final menu = Menu(id: repo.newId(), title: title);
    fire(repo.save(menu, isNew: true));
    fire(context.push(Routes.menu(menu.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recipes = {
      for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
        r.id: r,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menusTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'menus-fab',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.menuNew),
      ),
      body: AsyncView(
        value: ref.watch(menusProvider),
        data: (menus) => menus.isEmpty
            ? EmptyState(icon: Icons.restaurant_menu, message: l10n.menusEmpty)
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final m in menus)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_menu),
                        title: Text(m.title),
                        subtitle: Text(
                          [
                            if (DateTime.tryParse(m.date ?? '') case final d?)
                              DateFormat('EEE, d. MMM', 'de').format(d),
                            l10n.menuPersons(m.servings),
                            [
                              for (final c in m.ordered)
                                ?recipes[c.recipeId]?.title,
                            ].join(', '),
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                        onTap: () => context.push(Routes.menu(m.id)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
