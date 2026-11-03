import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';

/// Profile avatar in the app bar that opens the settings.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).profileTooltip,
      onPressed: () => context.push(Routes.settings),
      icon: const CircleAvatar(child: Icon(Icons.person)),
    );
  }
}
