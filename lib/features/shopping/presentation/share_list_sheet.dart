import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/url_opener.dart';
import '../../sharing/domain/shared_list.dart';
import '../../sharing/domain/shared_recipe.dart';
import '../domain/shopping_item.dart';
import 'shopping_list_screen.dart';

/// Share button on the shopping list: as text, or as a live link someone
/// without BaCo can open in the browser and tick off; active links can be
/// stopped here.
Future<void> showShareListSheet(
  BuildContext context,
  WidgetRef ref,
  List<ShoppingItem> items,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _ShareListSheet(items: items),
);

class _ShareListSheet extends ConsumerWidget {
  const _ShareListSheet({required this.items});

  final List<ShoppingItem> items;

  void _shareText(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    fire(
      ref
          .read(sharerProvider)
          .shareText(
            shoppingShareText(
              items,
              ref.read(ingredientsByIdProvider),
              title: l10n.shoppingShareTitle,
              aisleName: l10n.aisle,
              display: ref.read(unitDisplayProvider),
              order: ref.read(aisleOrderProvider),
              byStore: ref.read(shoppingByStoreProvider)
                  ? (
                      stores: ref.read(storesProvider),
                      anywhere: l10n.storeAnywhere,
                    )
                  : null,
            ),
            subject: l10n.shoppingShareTitle,
          ),
    );
    Navigator.pop(context);
  }

  Future<void> _shareLink(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final validity = await showDialog<ShareValidity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.listLinkValidity),
        children: [
          for (final v in [
            ShareValidity.week,
            ShareValidity.month,
            ShareValidity.never,
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, v),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.shareValidity(v)),
              ),
            ),
        ],
      ),
    );
    final hid = ref.read(householdIdProvider);
    final uid = ref.read(authUserProvider).value?.uid;
    if (validity == null || hid == null || uid == null) return;
    final list = SharedList.create(
      householdId: hid,
      uid: uid,
      title: ref.read(householdProvider).value?.name ?? l10n.shoppingShareTitle,
      validity: validity,
    );
    fire(ref.read(sharedListRepositoryProvider).create(list));
    await ref
        .read(sharerProvider)
        .shareText(
          l10n.listLinkText(
            list.title,
            Links.sharedList(list.token).toString(),
          ),
          subject: l10n.shoppingShareTitle,
        );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final links = [
      for (final l
          in ref.watch(sharedListsProvider).value ?? const <SharedList>[])
        if (!l.isExpired(now)) l,
    ];
    final hasOpen = items.any((i) => !i.checked);
    // Keeps the household (name for the link title) loaded.
    ref.watch(householdProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              l10n.shareShoppingList,
              style: theme.textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: Text(l10n.listShareText),
            subtitle: Text(l10n.listShareTextHint),
            enabled: hasOpen,
            onTap: () => _shareText(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.listShareLink),
            subtitle: Text(l10n.listShareLinkHint),
            onTap: () => _shareLink(context, ref),
          ),
          if (links.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.listLinksActive,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final l in links)
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(l.title),
                subtitle: Text(
                  l.expiresAt == null
                      ? l10n.sentNoExpiry
                      : l10n.sentValidUntil(
                          MaterialLocalizations.of(context)
                              .formatShortDate(l.expiresAt!),
                        ),
                ),
                trailing: IconButton(
                  tooltip: l10n.listLinkStop,
                  icon: const Icon(Icons.link_off),
                  onPressed: () => fire(
                    ref.read(sharedListRepositoryProvider).delete(l.token),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
