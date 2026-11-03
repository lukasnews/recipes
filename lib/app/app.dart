import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/empty_state.dart';
import '../core/widgets/l10n_ext.dart';
import '../l10n/app_localizations.dart';
import 'messenger.dart';
import 'router.dart';
import 'theme.dart';

const _localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class RecipesApp extends ConsumerWidget {
  const RecipesApp({super.key, this.firebaseReady = true});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!firebaseReady) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('de', 'AT'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        home: const _FirebaseMissingScreen(),
      );
    }
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('de', 'AT'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _localizationsDelegates,
    );
  }
}

class _FirebaseMissingScreen extends StatelessWidget {
  const _FirebaseMissingScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.firebaseMissingTitle)),
      body: EmptyState(
        icon: Icons.cloud_off_outlined,
        message: l10n.firebaseMissingBody,
      ),
    );
  }
}
