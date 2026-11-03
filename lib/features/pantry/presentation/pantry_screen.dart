import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/profile_button.dart';
import '../../../l10n/app_localizations.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPantry),
        actions: const [ProfileButton()],
      ),
      body: EmptyState(icon: Icons.kitchen_outlined, message: l10n.pantryEmpty),
    );
  }
}
