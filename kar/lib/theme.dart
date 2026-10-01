import 'package:flutter/material.dart';

/// Theme de l'application.
///
/// La couleur principale reprend celle du manifeste PWA et des icones generees
/// par `tool/generate_icons.dart`, pour que l'application et son icone
/// d'installation restent coherentes.
abstract final class AppTheme {
  static const Color primaire = Color(0xFF1E88E5);
  static const Color secondaire = Color(0xFF00BFA5);

  static ThemeData clair() => _construire(Brightness.light);
  static ThemeData sombre() => _construire(Brightness.dark);

  static ThemeData _construire(Brightness clarte) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaire,
      brightness: clarte,
    );

    return ThemeData(
      colorScheme: scheme.copyWith(
        secondary: secondaire,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}