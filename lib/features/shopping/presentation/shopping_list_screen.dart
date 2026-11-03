import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/profile_button.dart';
import '../../../l10n/app_localizations.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navShopping),
        actions: const [ProfileButton()],
      ),
      body: EmptyState(
        icon: Icons.shopping_cart_outlined,
        message: l10n.shoppingEmpty,
      ),
    );
  }
}
