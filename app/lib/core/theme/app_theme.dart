import 'package:flutter/material.dart';

/// Theming centralisé. Aucune couleur/taille en dur ailleurs dans l'app :
/// tout passe par `Theme.of(context)`.
abstract final class AppTheme {
  static const _seed = Color(0xFF5B5BD6);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48), // cible tactile ≥ 48dp (a11y)
        ),
      ),
    );
  }
}
