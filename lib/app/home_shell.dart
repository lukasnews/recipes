import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/household/presentation/member_sync.dart';
import '../features/import/presentation/share_listener.dart';
import '../features/onboarding/presentation/onboarding.dart';
import '../features/recipes/presentation/photo_queue_runner.dart';
import '../l10n/app_localizations.dart';

/// Bottom navigation shell with the four main tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MemberSync(
      child: PhotoQueueRunner(
        child: OnboardingGate(
          child: ShareListener(
            child: Scaffold(
              body: shell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: (index) => shell.goBranch(
                  index,
                  initialLocation: index == shell.currentIndex,
                ),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book),
                    label: l10n.navRecipes,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: const Icon(Icons.calendar_month),
                    label: l10n.navMealPlan,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    selectedIcon: const Icon(Icons.shopping_cart),
                    label: l10n.navShopping,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.kitchen_outlined),
                    selectedIcon: const Icon(Icons.kitchen),
                    label: l10n.navPantry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
