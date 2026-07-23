// lib/ui/haptics.dart — tiny haptics seam (v0.3.1 F12).
// Vibration on the game's key beats, honoring the settings toggle. Cheap on
// Android, no-op on platforms without a vibrator, and null-safe in tests
// (AudioService.instance is null there, so haptics simply stay off unless
// the settings say otherwise — every call is best-effort).
import 'package:flutter/services.dart';
import '../audio/audio_service.dart';

class Haptics {
  static bool get _on => AudioService.instance?.settings.haptics ?? false;

  /// Die tap / assign / roll — a soft tick.
  static void light() {
    if (_on) HapticFeedback.lightImpact();
  }

  /// Hits landing (either side).
  static void medium() {
    if (_on) HapticFeedback.mediumImpact();
  }

  /// Deaths, defeat, victory — the big beats.
  static void heavy() {
    if (_on) HapticFeedback.heavyImpact();
  }
}
