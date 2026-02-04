import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
      inputDecorationTheme: _inputTheme(isDark: false),
      elevatedButtonTheme: _buttonTheme(isDark: false),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        surface: Color(0xFF101010),
        onSurface: Colors.white,
      ),
      inputDecorationTheme: _inputTheme(isDark: true),
      elevatedButtonTheme: _buttonTheme(isDark: true),
    );
  }

  static InputDecorationTheme _inputTheme({required bool isDark}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark ? Colors.white24 : Colors.black12,
        width: 1.2,
      ),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F7),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: isDark ? Colors.white54 : Colors.black54,
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
    );
  }

  static ElevatedButtonThemeData _buttonTheme({required bool isDark}) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
