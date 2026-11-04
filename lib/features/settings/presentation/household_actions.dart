import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../household/domain/household.dart';
import '../data/account_deletion.dart';

/// Changes the own name: account, user doc and member entry (other
/// households follow via MemberSync when switched to).
Future<void> editDisplayName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final l10n = context.l10n;
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: current),
  );
  final trimmed = name?.trim() ?? '';
  final uid = ref.read(authUserProvider).value?.uid;
  if (trimmed.isEmpty || trimmed == current || uid == null) return;
  fire(ref.read(authRepositoryProvider).updateDisplayName(trimmed));
  fire(ref.read(householdRepositoryProvider).setDisplayName(uid, trimmed));
  if (ref.read(householdIdProvider) != null) {
    fire(ref.read(memberRepositoryProvider).ensure(uid, trimmed));
  }
  if (context.mounted) showSnack(context, l10n.nameChanged);
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.editNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: InputDecoration(
          labelText: l10n.nameLabel,
          helperText: l10n.editNameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// New invite code; the old one stops working.
Future<void> renewInviteCode(
  BuildContext context,
  WidgetRef ref,
  Household household,
) async {
  final l10n = context.l10n;
  final ok = await confirmDialog(
    context,
    title: l10n.renewInviteTitle,
    message: l10n.renewInviteMessage(household.inviteCode),
    confirmLabel: l10n.renewInviteConfirm,
  );
  if (!ok || !context.mounted) return;
  try {
    final code = await ref
        .read(householdRepositoryProvider)
        .renewInviteCode(household.id, household.inviteCode);
    if (context.mounted) showSnack(context, l10n.renewInviteDone(code));
  } catch (e, st) {
    reportError(e, st);
    if (context.mounted) showSnack(context, l10n.needsOnline);
  }
}

/// Leaves the household; as the last member it is deleted.
Future<void> leaveHousehold(
  BuildContext context,
  WidgetRef ref,
  Household household,
) async {
  final l10n = context.l10n;
  final uid = ref.read(authUserProvider).value?.uid;
  if (uid == null) return;
  final service = ref.read(accountDeletionProvider);
  final last = await service.isLastMember(uid, household.id);
  if (!context.mounted) return;
  final ok = await confirmDialog(
    context,
    title: l10n.leaveHouseholdTitle(household.name),
    message: last ? l10n.leaveHouseholdLastMessage : l10n.leaveHouseholdMessage,
    confirmLabel: last ? l10n.leaveHouseholdDelete : l10n.leaveHouseholdConfirm,
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    await service.leaveHousehold(uid, household.id);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.leftHousehold(household.name))),
    );
    // Remaining households: back to the recipes; none: the router shows
    // the setup screen by itself.
    router.go(Routes.recipes);
  } on NeedsOnlineException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.needsOnline)));
  } catch (e, st) {
    reportError(e, st);
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountFailed)));
  }
}
