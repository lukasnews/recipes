import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import 'backup_actions.dart';
import 'delete_account.dart';
import 'household_actions.dart';

/// Einstellungen → Konto: name, sign out, delete account.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAccount)),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.bestName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: IconButton(
              tooltip: l10n.editNameTitle,
              onPressed: () =>
                  editDisplayName(context, ref, user?.bestName ?? ''),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () {
              fire(ref.read(authRepositoryProvider).signOut());
              context.pop();
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text(
              l10n.deleteAccountTitle,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text(l10n.deleteAccountSubtitle),
            onTap: () => deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Einstellungen → Haushalt: name, invite code, switch/add, leave.
class HouseholdSettingsScreen extends ConsumerWidget {
  const HouseholdSettingsScreen({super.key});

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final name = (await showTextInputDialog(
      context,
      title: l10n.renameHousehold,
      label: l10n.householdNameLabel,
      initial: current,
      confirmLabel: l10n.save,
    ))?.trim();
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
    final household = ref.watch(householdProvider).value;
    final householdIds = ref.watch(appUserProvider).value?.householdIds ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsHousehold)),
      body: household == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
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
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(l10n.inviteCodeTitle),
                  subtitle: Text(l10n.inviteCodeHelp),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: household.inviteCode),
                          );
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
                      TextButton.icon(
                        onPressed: () =>
                            renewInviteCode(context, ref, household),
                        icon: const Icon(Icons.autorenew),
                        label: Text(l10n.renewInvite),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                if (householdIds.length > 1)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l10n.switchHousehold),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _switch(context, ref, householdIds, household.id),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_home_outlined),
                  title: Text(l10n.addHousehold),
                  subtitle: Text(l10n.addHouseholdSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.addHousehold),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.leaveHousehold),
                  onTap: () => leaveHousehold(context, ref, household),
                ),
              ],
            ),
    );
  }
}

/// Einstellungen → Einkaufen: shops & flyers, aisle order.
class ShoppingSettingsScreen extends ConsumerWidget {
  const ShoppingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsShopping)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.storesTitle),
            subtitle: Text(ref.watch(storesProvider).join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.stores),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered),
            title: Text(l10n.aisleOrderTitle),
            subtitle: Text(l10n.aisleOrderSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.aisleOrder),
          ),
        ],
      ),
    );
  }
}

/// Einstellungen → Daten & Teilen: backup, restore, sent recipes.
class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsData)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.backupExport),
            subtitle: Text(l10n.backupExportSubtitle),
            onTap: () => exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.restoreTitle),
            subtitle: Text(l10n.restoreSubtitle),
            onTap: () => showRestoreHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: Text(l10n.sentTitle),
            subtitle: Text(l10n.sentSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.sentRecipes),
          ),
        ],
      ),
    );
  }
}
