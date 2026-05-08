import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const seedColor = Color(0xFF1565C0);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
    );
  }
}
