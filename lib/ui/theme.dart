// Emberdelve visual language: a dark "ember cavern" — near-black warm
// background, deep brown surfaces, ember-orange light sources. One place for
// every color/spacing decision so screens stay consistent.
import 'package:flutter/material.dart';

/// Semantic palette. Widgets read these, never raw hex.
abstract final class Ember {
  static const Color bg = Color(0xFF171210); // cavern dark
  static const Color surface = Color(0xFF241B16); // card brown
  static const Color surfaceHigh = Color(0xFF2F231B); // raised card
  static const Color line = Color(0xFF4A382C); // hairline borders

  static const Color primary = Color(0xFFFF7A29); // ember orange
  static const Color primaryBright = Color(0xFFFFA45C);
  static const Color glow = Color(0x33FF7A29); // soft ember glow

  static const Color text = Color(0xFFF2E7DC); // warm off-white
  static const Color textDim = Color(0xFFA6907E); // muted warm gray

  static const Color hp = Color(0xFFE4573D); // vitals red-orange
  static const Color block = Color(0xFF5FA8B8); // cool steel/teal
  static const Color danger = Color(0xFFFF4B3A); // incoming damage
  static const Color good = Color(0xFF8FBF6F); // heal / victory
  static const Color eliteGold = Color(0xFFE7B44A); // elite accents
  static const Color bossPurple = Color(0xFFB05CFF); // boss accents
}

/// Corner radius scale.
abstract final class EmberRadius {
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(12));
}

ThemeData emberTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Ember.primary,
    brightness: Brightness.dark,
  ).copyWith(
    surface: Ember.bg,
    primary: Ember.primary,
    onPrimary: const Color(0xFF241205),
    secondary: Ember.block,
    error: Ember.danger,
  );

  const display = TextStyle(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: Ember.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ember.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displayLarge: display,
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: Ember.text,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: Ember.text,
      ),
      bodyMedium: TextStyle(color: Ember.text, height: 1.35),
      bodySmall: TextStyle(color: Ember.textDim, height: 1.3),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ember.primary,
        foregroundColor: const Color(0xFF241205),
        minimumSize: const Size(64, 52),
        shape: const RoundedRectangleBorder(borderRadius: EmberRadius.chip),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ember.text,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: Ember.line, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: EmberRadius.chip),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    ),
  );
}
