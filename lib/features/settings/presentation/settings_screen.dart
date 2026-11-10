import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/display_units.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/url_opener.dart';
import '../../../l10n/app_localizations.dart';

/// Short overview; details live on sub pages (Konto, Haushalt, Einkaufen,
/// Daten & Teilen) so the list stays one screen long.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _unitDisplay(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final uid = ref.read(authUserProvider).value?.uid;
    final picked = await showDialog<UnitDisplay>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unitDisplayTitle),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: RadioGroup<UnitDisplay>(
          groupValue: ref.read(unitDisplayProvider),
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in UnitDisplay.values)
                RadioListTile<UnitDisplay>(
                  value: mode,
                  title: Text(unitDisplayName(l10n, mode)),
                  subtitle: Text(unitDisplayHint(l10n, mode)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || uid == null) return;
    fire(
      ref.read(householdRepositoryProvider).setUnitDisplay(uid, picked.name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).value;
    final household = ref.watch(householdProvider).value;

    ListTile entry(
      IconData icon,
      String title,
      String? subtitle,
      VoidCallback onTap, {
      Widget trailing = const Icon(Icons.chevron_right),
    }) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                user?.bestName ?? '',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(user?.email ?? l10n.settingsAccount),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.settingsAccount),
            ),
          ),
          if (household != null) ...[
            entry(
              Icons.home_outlined,
              l10n.settingsHousehold,
              '${household.name} · '
              '${l10n.membersCount(household.memberIds.length)}',
              () => context.push(Routes.settingsHousehold),
            ),
            entry(
              Icons.health_and_safety_outlined,
              l10n.allergiesTitle,
              l10n.allergiesSubtitle,
              () => context.push(Routes.allergies),
            ),
            entry(
              Icons.egg_outlined,
              l10n.ingredientsManage,
              l10n.ingredientsManageSubtitle,
              () => context.push(Routes.ingredients),
            ),
            entry(
              Icons.category_outlined,
              l10n.categoriesTitle,
              l10n.categoriesSubtitle,
              () => context.push(Routes.categories),
            ),
            entry(
              Icons.shopping_cart_outlined,
              l10n.settingsShopping,
              l10n.settingsShoppingSubtitle,
              () => context.push(Routes.settingsShopping),
            ),
          ],
          entry(
            Icons.scale_outlined,
            l10n.unitDisplayTitle,
            unitDisplayName(l10n, ref.watch(unitDisplayProvider)),
            () => _unitDisplay(context, ref),
            trailing: const Icon(Icons.expand_more),
          ),
          if (household != null)
            entry(
              Icons.cloud_sync_outlined,
              l10n.settingsData,
              l10n.settingsDataSubtitle,
              () => context.push(Routes.settingsData),
            ),
          entry(
            Icons.privacy_tip_outlined,
            l10n.privacyPolicy,
            null,
            () => fire(ref.read(urlOpenerProvider).open(Links.privacy)),
            trailing: const Icon(Icons.open_in_new),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.buildInfo(
                const String.fromEnvironment(
                  'BUILD_NUMBER',
                  defaultValue: 'dev',
                ),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String unitDisplayName(AppLocalizations l10n, UnitDisplay mode) =>
    switch (mode) {
      UnitDisplay.original => l10n.unitDisplayOriginal,
      UnitDisplay.metric => l10n.unitDisplayMetric,
      UnitDisplay.austrian => l10n.unitDisplayAustrian,
    };

String unitDisplayHint(AppLocalizations l10n, UnitDisplay mode) =>
    switch (mode) {
      UnitDisplay.original => l10n.unitDisplayOriginalHint,
      UnitDisplay.metric => l10n.unitDisplayMetricHint,
      UnitDisplay.austrian => l10n.unitDisplayAustrianHint,
    };
