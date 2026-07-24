// lib/ui/haptics.dart — tiny haptics seam (v0.3.1 F12, rebuilt v0.3.4).
//
// v0.3.4 bugfix: the original implementation used Flutter's HapticFeedback,
// which maps to Android's View.performHapticFeedback(). That call is silently
// gated by the SYSTEM "touch feedback / touch vibration" setting — disabled
// on many phones out of the box — and since Android 13 apps cannot override
// that gate. Result: the in-game Haptics toggle did nothing on those devices
// (owner-reported on the v0.3.2 APK). Games are expected to drive the
// Vibrator service directly, which needs the (normal, install-time) VIBRATE
// permission and a tiny platform channel — see MainActivity.kt.
//
// Order of attempts per beat, all best-effort and crash-proof:
//   1. `emberdelve/haptics` MethodChannel → real Vibrator one-shot with
//      per-beat duration/amplitude (works regardless of system touch-feedback
//      setting; returns false if the device has no vibrator).
//   2. HapticFeedback.*Impact() fallback — iOS and any host without the
//      channel (widget tests throw MissingPluginException on step 1).
//
// Honors the in-game settings toggle; null-safe in tests (AudioService
// .instance is null there, so haptics simply stay off).
import 'package:flutter/services.dart';
import '../audio/audio_service.dart';

class Haptics {
  static const MethodChannel channel = MethodChannel('emberdelve/haptics');

  static bool get _on => AudioService.instance?.settings.haptics ?? false;

  /// Die tap / assign / roll — a soft tick.
  static void light() {
    if (_on) _beat(ms: 18, amplitude: 90, fallback: HapticFeedback.lightImpact);
  }

  /// Hits landing (either side).
  static void medium() {
    if (_on) {
      _beat(ms: 38, amplitude: 170, fallback: HapticFeedback.mediumImpact);
    }
  }

  /// Deaths, defeat, victory — the big beats.
  static void heavy() {
    if (_on) {
      _beat(ms: 70, amplitude: 255, fallback: HapticFeedback.heavyImpact);
    }
  }

  /// Settings-screen preview: fires even while the toggle logic is mid-flight
  /// so flipping Haptics ON always answers with a buzz the user can feel.
  static void preview() {
    _beat(ms: 38, amplitude: 170, fallback: HapticFeedback.mediumImpact);
  }

  static Future<void> _beat({
    required int ms,
    required int amplitude,
    required Future<void> Function() fallback,
  }) async {
    try {
      final handled = await channel.invokeMethod<bool>(
          'vibrate', {'ms': ms, 'amplitude': amplitude});
      if (handled == true) return;
    } catch (_) {
      // Channel missing (iOS/web/tests) or platform error — fall through.
    }
    try {
      await fallback();
    } catch (_) {
      // Haptics must never crash gameplay.
    }
  }
}
