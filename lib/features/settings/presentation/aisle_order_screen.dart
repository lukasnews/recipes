import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../ingredients/domain/ingredient.dart';

/// Drag the shopping list sections into the order of the own store.
class AisleOrderScreen extends ConsumerWidget {
  const AisleOrderScreen({super.key});

  void _save(WidgetRef ref, List<Aisle>? order) {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    fire(
      ref
          .read(householdRepositoryProvider)
          .setAisleOrder(uid, order?.map((a) => a.name).toList()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final order = ref.watch(aisleOrderProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aisleOrderTitle),
        actions: [
          TextButton(
            onPressed: () => _save(ref, null),
            child: Text(l10n.aisleOrderReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.aisleOrderHint),
          ),
          Expanded(
            child: ReorderableListView(
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              onReorderItem: (from, to) {
                final next = [...order];
                next.insert(to, next.removeAt(from));
                _save(ref, next);
              },
              children: [
                for (final (i, a) in order.indexed)
                  ListTile(
                    key: ValueKey(a),
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(l10n.aisle(a)),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: Icon(
                        Icons.drag_handle,
                        semanticLabel: l10n.aisleOrderDrag,
                      ),
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
