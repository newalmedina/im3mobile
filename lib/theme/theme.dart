import 'package:flutter/material.dart';

/// Colores de la app, sacados del logo de IM3.
class AppColors {
  // Colores principales (logo IM3)
  static const Color primary = Color(0xFF04368A); // Azul IM3
  static const Color secondary = Color(
    0xFF79B52A,
  ); // Verde IM3 (punto de la "i")
  static const Color tertiary = Color(0xFF2D579E); // Azul claro IM3
  static const Color quaternary = Color(0xFFABBCD8); // Azul muy claro IM3

  // Colores de estado
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color success = Color(0xFF22C55E); // Green 500
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color warning = Color(0xFFFACC15); // Yellow 400

  // Fondo y texto
  static const Color background = Color(0xFFF9FAFB); // Gray 50
  static const Color text = Color(0xFF111827); // Gray 900
}

/// Tema general de la app. Se usa en main.dart: theme: AppTheme.light
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
