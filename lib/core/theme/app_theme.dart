import 'package:flutter/material.dart';

/// The purple from the PypeCRM logo (#8C5FA8, same value as the web app's
/// `plum-500`), so the dialer reads as part of the same product.
const kBrandColor = Color(0xFF8C5FA8);

/// Background for a secondary surface nested *inside* a card — e.g. a
/// footer action bar under a call-history row — one step lighter than the
/// card itself ([kCardSurfaceColor]) so it reads as a distinct sub-region
/// without introducing a whole new elevation level.
const kNestedSurfaceColor = Color(0xFF2A2A2A);

const kAppBackgroundColor = Color(0xFF121212);
const kCardSurfaceColor = Color(0xFF1E1E1E);
const kOnDarkPrimaryText = Color(0xFFF5F5F5);
const kOnDarkMutedText = Color(0xFFABABAB);

class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kBrandColor),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBrandColor.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBrandColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  /// The app's only theme in practice (`app.dart` wires this up, not
  /// `light`) — a near-black, card-based dark theme matching the reference
  /// competitor app's look, with [kBrandColor] standing in for its
  /// yellow/orange accent everywhere (FAB, active nav tab, focused inputs).
  static ThemeData dark = () {
    final base = ColorScheme.fromSeed(seedColor: kBrandColor, brightness: Brightness.dark);
    final scheme = base.copyWith(
      surface: kAppBackgroundColor,
      onSurface: kOnDarkPrimaryText,
      onSurfaceVariant: kOnDarkMutedText,
      surfaceContainerHighest: kCardSurfaceColor,
      surfaceContainerHigh: kNestedSurfaceColor,
      surfaceContainer: kCardSurfaceColor,
      surfaceContainerLow: kAppBackgroundColor,
      surfaceContainerLowest: kAppBackgroundColor,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: kAppBackgroundColor,
      cardColor: kCardSurfaceColor,
      dialogTheme: const DialogThemeData(backgroundColor: kCardSurfaceColor),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: kOnDarkPrimaryText,
            displayColor: kOnDarkPrimaryText,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBrandColor.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: kOnDarkMutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBrandColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: kBrandColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kAppBackgroundColor,
        foregroundColor: kOnDarkPrimaryText,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kCardSurfaceColor,
        modalBackgroundColor: kCardSurfaceColor,
      ),
      iconTheme: const IconThemeData(color: kOnDarkPrimaryText),
      dividerColor: kNestedSurfaceColor,
    );
  }();
}
