import 'package:flutter/material.dart';

/// Material 3 theme with large touch targets (cooking with wet hands).
abstract final class AppTheme {
  static const _seed = Color(0xFF4E7D3A);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    const minTarget = Size(56, 56);
    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(minTarget)),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(minTarget)),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
