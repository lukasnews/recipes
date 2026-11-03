import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/ingredient.dart';

/// Lets the user pick which of the two to keep, then merges.
/// Returns true when merged.
Future<bool> confirmMerge(
  BuildContext context,
  WidgetRef ref,
  Ingredient source,
  Ingredient target,
) async {
  final l10n = context.l10n;
  var keep = target;
  var drop = source;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.mergeAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: target.id, label: Text(target.name)),
                ButtonSegment(value: source.id, label: Text(source.name)),
              ],
              selected: {keep.id},
              onSelectionChanged: (s) => setState(() {
                keep = s.first == target.id ? target : source;
                drop = s.first == target.id ? source : target;
              }),
            ),
            const SizedBox(height: 16),
            Text(l10n.mergeConfirm(drop.name, keep.name)),
            if (drop.baseUnit != keep.baseUnit) ...[
              const SizedBox(height: 8),
              Text(
                l10n.mergeUnitMismatch(drop.name),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.mergeAction),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  fire(
    ref
        .read(ingredientRepositoryProvider)
        .merge(
          source: drop,
          target: keep,
          recipes: ref.read(recipesProvider).value ?? const [],
          sourcePantry: ref.read(pantryProvider).value?[drop.id],
          shopping: ref.read(shoppingProvider).value ?? const [],
        ),
  );
  showSnack(context, l10n.mergeDone);
  return true;
}
