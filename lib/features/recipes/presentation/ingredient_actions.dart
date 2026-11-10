import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/messenger.dart';
import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../household/domain/allergen.dart';
import '../../pantry/domain/pantry_item.dart';
import '../domain/amount_scaling.dart';
import '../domain/recipe.dart';
import '../domain/substitute.dart';

enum IngredientAction { scale, substitute }

/// Long press on an ingredient line: convert the recipe to this amount, or
/// ask the AI for a replacement.
Future<IngredientAction?> showIngredientActions(
  BuildContext context, {
  required String label,
  required bool canScale,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<IngredientAction>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (canScale)
            ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(l10n.scaleToAmount),
              subtitle: Text(l10n.scaleToAmountHint),
              onTap: () => Navigator.pop(context, IngredientAction.scale),
            ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.substituteSuggest),
            subtitle: Text(l10n.substituteSuggestHint),
            onTap: () => Navigator.pop(context, IngredientAction.substitute),
          ),
        ],
      ),
    ),
  );
}

/// "Wie viel hast du?" in the line's unit, prefilled with the pantry stock.
/// Returns the amount, or null when cancelled.
Future<double?> askAvailableAmount(
  BuildContext context,
  WidgetRef ref,
  RecipeIngredient line,
) async {
  final l10n = context.l10n;
  final ing = ref.read(ingredientsByIdProvider)[line.ingredientId];
  final stock = stockInLineUnit(
    line,
    ing,
    ref.read(pantryProvider).value?[line.ingredientId],
  );
  final name = ing?.name ?? line.name ?? line.rawText;
  final text = await showTextInputDialog(
    context,
    title: l10n.scaleToAmountTitle(name),
    label: l10n.scaleToAmountLabel,
    initial: stock == null ? '' : formatAmount(stock, fractions: false),
    helper: l10n.scaleToAmountNeeded(
      [formatAmount(line.amount!), ?line.unit].join(' '),
    ),
    suffix: line.unit,
    confirmLabel: l10n.scaleToAmountConfirm,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );
  final have = text == null ? null : parseUserNumber(text);
  if (text != null && (have == null || have <= 0)) {
    showGlobalSnack(l10n.invalidNumber);
    return null;
  }
  return have;
}

/// Asks the AI for replacements of [missingLine] ("200 ml Buttermilch")
/// and shows them; pantry items are preferred.
Future<void> showSubstitutes(
  BuildContext context,
  WidgetRef ref, {
  required Recipe recipe,
  required String missingLine,
}) async {
  final l10n = context.l10n;
  final ingredients = ref.read(ingredientsByIdProvider);
  final pantry = [
    for (final p in ref.read(pantryProvider).value?.values ?? <PantryItem>[])
      if (p.amount > 0) ?ingredients[p.ingredientId]?.name,
  ];
  final avoid = {
    for (final m in ref.read(membersProvider).value ?? <HouseholdMember>[])
      ...m.allergens,
  }.map(l10n.allergen).toList();
  final future = ref
      .read(recipeExtractorProvider.future)
      .then(
        (e) => e.suggestSubstitutes(
          substitutePrompt(
            title: recipe.title,
            missingLine: missingLine,
            otherLines: [
              for (final l in recipe.ingredients)
                if (l.rawText != missingLine) l.rawText,
            ],
          ),
          pantry: pantry,
          avoid: avoid,
        ),
      )
      .catchError((Object e, StackTrace st) {
        reportError(e, st);
        throw e;
      });
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.substituteTitle(missingLine)),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<Substitute>>(
          future: future,
          builder: (context, snap) {
            if (snap.hasError) return Text(l10n.substituteFailed);
            final list = snap.data;
            if (list == null) {
              return Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  Expanded(child: Text(l10n.substituteThinking)),
                ],
              );
            }
            if (list.isEmpty) return Text(l10n.substituteNone);
            return ListView(
              shrinkWrap: true,
              children: [
                for (final s in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.fromPantry
                          ? Icons.kitchen_outlined
                          : Icons.shopping_basket_outlined,
                      semanticLabel: s.fromPantry
                          ? l10n.substituteFromPantry
                          : null,
                    ),
                    title: Text(s.replacement),
                    subtitle: Text(
                      [
                        if (s.fromPantry) l10n.substituteFromPantry,
                        if (s.note.isNotEmpty) s.note,
                      ].join(' · '),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  l10n.substituteDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}
