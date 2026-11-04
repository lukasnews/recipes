import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/l10n_ext.dart';

/// Shows a short introduction over the app once per person
/// (users/{uid}.onboardingDone).
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  // Hides at once on finish, before the user doc round-trip.
  var _dismissed = false;

  void _finish() {
    setState(() => _dismissed = true);
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid != null) {
      fire(ref.read(householdRepositoryProvider).setOnboardingDone(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(
      appUserProvider.select((u) => u.value?.onboardingDone ?? true),
    );
    return Stack(
      children: [
        widget.child,
        if (!done && !_dismissed)
          Positioned.fill(child: _Onboarding(onDone: _finish)),
      ],
    );
  }
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pages = [
      (Icons.add_a_photo_outlined, l10n.onboarding1Title, l10n.onboarding1Text),
      (Icons.kitchen_outlined, l10n.onboarding2Title, l10n.onboarding2Text),
      (
        Icons.soup_kitchen_outlined,
        l10n.onboarding3Title,
        l10n.onboarding3Text,
      ),
    ];
    final last = _page == pages.length - 1;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final (icon, title, text) in pages)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 64,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              icon,
                              size: 64,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            text,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: last
                      ? widget.onDone
                      : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                  child: Text(last ? l10n.onboardingStart : l10n.cookNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
