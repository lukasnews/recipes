import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../data/household_repository.dart';

class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String uid) action) async {
    final user = ref.read(authUserProvider).value;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final repo = ref.read(householdRepositoryProvider);
      await repo.ensureUser(user.uid, user.bestName);
      await action(user.uid);
    } on InviteNotFoundException {
      if (mounted) setState(() => _error = l10n.inviteNotFound);
    } catch (e) {
      if (mounted) setState(() => _error = '${l10n.needsOnline}\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.fieldRequired);
      return;
    }
    await _run((uid) async {
      final seed = await ref.read(seedIngredientsProvider.future);
      await ref
          .read(householdRepositoryProvider)
          .createHousehold(uid: uid, name: name, seed: seed);
    });
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.fieldRequired);
      return;
    }
    await _run(
      (uid) => ref
          .read(householdRepositoryProvider)
          .joinHousehold(uid: uid, code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.householdSetupTitle),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: Text(l10n.signOut),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.householdSetupIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(l10n.householdCreateTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.householdNameLabel,
              hintText: l10n.householdNameHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(l10n.householdCreate),
          ),
          const SizedBox(height: 32),
          Text(l10n.householdJoinTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: l10n.inviteCodeLabel),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: Text(l10n.householdJoin),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
