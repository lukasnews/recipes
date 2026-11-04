import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/display_units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameHousehold),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.householdNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    final hid = ref.read(householdIdProvider);
    if (name == null || name.isEmpty || hid == null) return;
    fire(ref.read(householdRepositoryProvider).rename(hid, name));
  }

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
    String current,
  ) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.switchHousehold),
        children: [
          for (final id in ids)
            Consumer(
              builder: (context, ref, _) {
                final name = ref.watch(householdByIdProvider(id)).value?.name;
                return ListTile(
                  leading: Icon(
                    id == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(name ?? '…'),
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
        ],
      ),
    );
    final uid = ref.read(authUserProvider).value?.uid;
    if (picked == null || picked == current || uid == null) return;
    fire(ref.read(householdRepositoryProvider).setActiveHousehold(uid, picked));
    if (context.mounted) context.go(Routes.recipes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).value;
    final household = ref.watch(householdProvider).value;
    final householdIds = ref.watch(appUserProvider).value?.householdIds ?? [];

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          section(l10n.settingsAccount),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.bestName ?? ''),
            subtitle: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          if (household != null) ...[
            section(l10n.settingsHousehold),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(household.name),
              subtitle: Text(l10n.membersCount(household.memberIds.length)),
              trailing: IconButton(
                tooltip: l10n.renameHousehold,
                onPressed: () => _rename(context, ref, household.name),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            if (householdIds.length > 1)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.switchHousehold),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _switch(context, ref, householdIds, household.id),
              ),
            ListTile(
              leading: const Icon(Icons.add_home_outlined),
              title: Text(l10n.addHousehold),
              subtitle: Text(l10n.addHouseholdSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.addHousehold),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: Text(l10n.inviteCodeTitle),
              subtitle: Text(l10n.inviteCodeHelp),
              trailing: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: household.inviteCode));
                  showSnack(context, l10n.copied);
                },
                icon: const Icon(Icons.copy),
                label: Text(
                  household.inviteCode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.allergiesTitle),
              subtitle: Text(l10n.allergiesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.allergies),
            ),
            ListTile(
              leading: const Icon(Icons.egg_outlined),
              title: Text(l10n.ingredientsManage),
              subtitle: Text(l10n.ingredientsManageSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.ingredients),
            ),
          ],
          section(l10n.settingsDisplay),
          ListTile(title: Text(l10n.unitDisplayTitle)),
          RadioGroup<UnitDisplay>(
            groupValue: ref.watch(unitDisplayProvider),
            onChanged: (v) {
              if (v == null || user == null) return;
              fire(
                ref
                    .read(householdRepositoryProvider)
                    .setUnitDisplay(user.uid, v.name),
              );
            },
            child: Column(
              children: [
                for (final (mode, title, hint) in [
                  (
                    UnitDisplay.original,
                    l10n.unitDisplayOriginal,
                    l10n.unitDisplayOriginalHint,
                  ),
                  (
                    UnitDisplay.metric,
                    l10n.unitDisplayMetric,
                    l10n.unitDisplayMetricHint,
                  ),
                  (
                    UnitDisplay.austrian,
                    l10n.unitDisplayAustrian,
                    l10n.unitDisplayAustrianHint,
                  ),
                ])
                  RadioListTile<UnitDisplay>(
                    value: mode,
                    title: Text(title),
                    subtitle: Text(hint),
                  ),
              ],
            ),
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
