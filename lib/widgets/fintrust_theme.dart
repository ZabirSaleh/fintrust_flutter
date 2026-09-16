import 'package:flutter/material.dart';

class FintrustColors {
  static const ink = Color(0xFF02020A);
  static const paper = Color(0xFFF2F1F5);
  static const panel = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E4E9);
  static const muted = Color(0xFF73768A);
  static const mint = Color(0xFFB8F2D0);
  static const blue = Color(0xFF1221E2);
  static const navy = Color(0xFF0A0B5D);
  static const softBlue = Color(0xFFE8EAFF);
  static const profileAccent = Color(0xFFB13D57);
  static const amber = Color(0xFFFFC857);
  static const danger = Color(0xFFB42318);
}

ThemeData buildFintrustTheme({bool dark = false}) {
  final colorScheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? Colors.white : FintrustColors.ink,
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: FintrustColors.blue,
    onSecondary: Colors.white,
    error: FintrustColors.danger,
    onError: Colors.white,
    surface: dark ? const Color(0xFF050507) : FintrustColors.paper,
    onSurface: dark ? Colors.white : FintrustColors.ink,
  );
  final paper = dark ? const Color(0xFF050507) : FintrustColors.paper;
  final panel = dark ? const Color(0xFF111217) : FintrustColors.panel;
  final ink = dark ? Colors.white : FintrustColors.ink;
  final muted = dark ? const Color(0xFFA9ADBA) : FintrustColors.muted;
  final border = dark ? const Color(0xFF24262D) : FintrustColors.border;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: paper,
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.35,
        letterSpacing: 0,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.35,
        letterSpacing: 0,
        color: muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FintrustColors.blue, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FintrustColors.danger, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Colors.white : FintrustColors.ink,
        foregroundColor: dark ? Colors.black : Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: panel,
      indicatorColor: dark ? Colors.white : FintrustColors.ink,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          letterSpacing: 0,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? (dark ? Colors.black : Colors.white)
              : muted,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStateProperty.all(BorderSide(color: border)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? Colors.black : Colors.white)
              : ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? Colors.white : FintrustColors.ink)
              : panel,
        ),
      ),
    ),
  );
}
