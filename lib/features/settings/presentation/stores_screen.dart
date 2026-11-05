import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';

/// Einstellungen → "Geschäfte": the household's shops (order = order of the
/// shopping list by shop); add, remove, drag.
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  void _save(WidgetRef ref, List<String> stores) {
    final hid = ref.read(householdIdProvider);
    if (hid == null) return;
    fire(ref.read(householdRepositoryProvider).setStores(hid, stores));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stores = ref.watch(storesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await askStoreName(context);
          if (name != null && !stores.contains(name)) {
            _save(ref, [...stores, name]);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.storeNew),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.storesHint),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 96),
              onReorderItem: (from, to) {
                final next = [...stores];
                next.insert(to, next.removeAt(from));
                _save(ref, next);
              },
              children: [
                for (final (i, s) in stores.indexed)
                  ListTile(
                    key: ValueKey(s),
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(s),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _save(ref, [...stores]..removeAt(i)),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(
                            Icons.drag_handle,
                            semanticLabel: l10n.aisleOrderDrag,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Name of a new shop, trimmed; null when cancelled or empty.
Future<String?> askStoreName(BuildContext context) async {
  final l10n = context.l10n;
  final name = (await showTextInputDialog(
    context,
    title: l10n.storeNew,
    label: l10n.storeNameLabel,
    hint: l10n.storeNameHint,
    capitalization: TextCapitalization.words,
  ))?.trim();
  return name == null || name.isEmpty ? null : name;
}
