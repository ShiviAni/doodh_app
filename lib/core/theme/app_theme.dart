import 'package:flutter/material.dart';

/// Sizing tokens tuned for the delivery role: a user who is not fully literate,
/// often outdoors in morning sun, frequently one-handed while carrying a can.
class Sizes {
  Sizes._();

  /// Minimum tap target. Material's default is 48; we go well past it because
  /// a mistap here means a wrong milk record.
  static const double tapTarget = 72;

  /// The primary confirm button on the delivery card.
  static const double primaryButton = 96;

  static const double bodyText = 20;
  static const double titleText = 30;
  static const double hugeNumber = 56;

  static const double gap = 16;
  static const double gapLarge = 24;
  static const double radius = 20;
}

class AppTheme {
  AppTheme._();

  /// Green reads as "yes/delivered" and red as "no/skipped" near-universally.
  /// Both are always paired with an icon and a word, never colour alone.
  static const Color confirm = Color(0xFF15803D);
  static const Color decline = Color(0xFFB91C1C);
  static const Color pending = Color(0xFFB45309);
  static const seed = Color(0xFF0F766E);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: Sizes.bodyText),
        bodyLarge: TextStyle(fontSize: Sizes.bodyText + 2),
        titleLarge: TextStyle(
          fontSize: Sizes.titleText,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Size(width, height), not Size.fromHeight — the latter sets an
          // *infinite* minimum width, which lays out fine in a stretched
          // Column but throws the moment a button sits inside a Row.
          // Full-width is achieved by the parent stretching instead.
          minimumSize: const Size(64, Sizes.tapTarget),
          textStyle: const TextStyle(
            fontSize: Sizes.bodyText + 4,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Sizes.tapTarget),
          textStyle: const TextStyle(
            fontSize: Sizes.bodyText + 2,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sizes.gap,
          vertical: Sizes.gap,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
      ),
    );
  }
}
