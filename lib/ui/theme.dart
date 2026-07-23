// lib/ui/theme.dart — the design system as code (docs/design-system.md).
// Dark warm "delve" palette, 4/8pt spacing scale, Cinzel/Inter type scale.
// Accent is scarce so hierarchy stays honest (UXPeak: emphasize the right
// element — if everything is loud, nothing is).
import 'package:flutter/material.dart';

class EmberColors {
  static const bg = Color(0xFF141019);
  static const surface = Color(0xFF1E1826);
  static const raised = Color(0xFF2A2136);
  static const line = Color(0xFF3A3148);

  static const textPrimary = Color(0xFFEDE6DA);
  static const textDim = Color(0xFF9A8FA0);
  static const textDisabled = Color(0xFF5E5668);

  static const ember = Color(0xFFF08A2C); // primary CTA + embers
  static const gold = Color(0xFFE8C24A);
  static const hp = Color(0xFFE05656);
  static const block = Color(0xFF5B8DD9);
  static const success = Color(0xFF6FBF73);
  static const danger = Color(0xFFC24040);

  // Start node is warm ash, not stock green — everything on the map sits in
  // the warm-from-below palette (visuals.md #6).
  static const kindStart = Color(0xFF8A7B66);
  static const kindFight = Color(0xFF8C5959);
  static const kindElite = Color(0xFFB34D8C);
  static const kindRest = Color(0xFF5980A6);
  static const kindShop = Color(0xFFC7A64A);
  static const kindEvent = Color(0xFF7E6FC2);
  static const kindBoss = Color(0xFFD9731F);

  static Color kind(String k) {
    switch (k) {
      case 'start':
        return kindStart;
      case 'fight':
        return kindFight;
      case 'elite':
        return kindElite;
      case 'rest':
        return kindRest;
      case 'shop':
        return kindShop;
      case 'event':
        return kindEvent;
      case 'boss':
        return kindBoss;
    }
    return kindFight;
  }
}

class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;
}

// Type scale (docs/design-system.md §2). Weights carry hierarchy before size.
class EmberText {
  static const display = TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: EmberColors.textPrimary,
      letterSpacing: 0.5);
  static const h1 = TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 26,
      height: 1.18,
      fontWeight: FontWeight.w700,
      color: EmberColors.textPrimary);
  static const h2 = TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: EmberColors.textPrimary);
  static const body = TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      height: 1.5,
      color: EmberColors.textPrimary);
  static const bodyDim = TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      height: 1.5,
      color: EmberColors.textDim);
  // Big bright values (UXPeak: values over labels).
  static const value = TextStyle(
      fontFamily: 'Inter',
      fontSize: 26,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: EmberColors.textPrimary,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const label = TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: EmberColors.textDim);
  // Small UPPERCASE meta labels.
  static const micro = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: EmberColors.textDim,
      letterSpacing: 1.2);
}

/// Fade-through-black route transition — the stock Material slide is one of
/// the strongest "this is a Flutter app" tells, so it dies here globally.
class _FadeThroughBlackBuilder extends PageTransitionsBuilder {
  const _FadeThroughBlackBuilder();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    return ColoredBox(
      color: Colors.black,
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}

ThemeData buildEmberTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: EmberColors.bg,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      surface: EmberColors.surface,
      primary: EmberColors.ember,
      secondary: EmberColors.gold,
      error: EmberColors.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    // Kill stock focus/hover/highlight tints (de-Flutter pass, visuals.md #6).
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: EmberColors.ember.withValues(alpha: 0.12),
    dividerColor: EmberColors.line,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _FadeThroughBlackBuilder(),
      TargetPlatform.iOS: _FadeThroughBlackBuilder(),
      TargetPlatform.linux: _FadeThroughBlackBuilder(),
      TargetPlatform.macOS: _FadeThroughBlackBuilder(),
      TargetPlatform.windows: _FadeThroughBlackBuilder(),
    }),
  );
}
