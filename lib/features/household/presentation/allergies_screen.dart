import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/allergen.dart';

class AllergiesScreen extends ConsumerWidget {
  const AllergiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final uid = ref.watch(authUserProvider).value?.uid;
    final members = ref.watch(membersProvider).value ?? const [];
    final me = members.where((m) => m.uid == uid).firstOrNull;
    final mine = me?.allergens ?? const <Allergen>{};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allergiesTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(l10n.allergiesMine, style: theme.textTheme.titleMedium),
          Text(l10n.allergiesMineHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in Allergen.values)
                FilterChip(
                  label: Text(l10n.allergen(a)),
                  selected: mine.contains(a),
                  onSelected: uid == null
                      ? null
                      : (on) => fire(
                          ref
                              .read(memberRepositoryProvider)
                              .setAllergens(
                                uid,
                                on ? {...mine, a} : (mine.toSet()..remove(a)),
                              ),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.allergiesHousehold, style: theme.textTheme.titleMedium),
          for (final m in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(m.displayName),
              subtitle: Text(
                m.allergens.isEmpty
                    ? l10n.allergiesNone
                    : l10n.allergenList(m.allergens),
              ),
            ),
        ],
      ),
    );
  }
}
