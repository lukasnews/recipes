import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/ingredient.dart';

/// Quick picker: which of the ingredient's terms is shown everywhere.
/// Saves right away; the other terms stay synonyms.
Future<void> showPreferredNameSheet(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
) async {
  final l10n = context.l10n;
  final picked = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              l10n.choosePreferredName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(l10n.displayNameHint),
          ),
          RadioGroup<String>(
            groupValue: ingredient.name,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                for (final term in [ingredient.name, ...ingredient.synonyms])
                  RadioListTile<String>(value: term, title: Text(term)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (picked == null || picked == ingredient.name || !context.mounted) return;
  fire(
    ref
        .read(ingredientRepositoryProvider)
        .save(ingredient.withPreferredName(picked)),
  );
  showSnack(context, l10n.preferredNameSaved(picked));
}
