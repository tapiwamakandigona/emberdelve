// game/haptics.dart — thin, settings-gated wrapper over HapticFeedback.
// Feel spec: haptics confirm IMPACT (taking a hit, kill confirm, boss
// beats), never ambient events — vibration spam numbs the channel. Gated on
// the persisted `haptics` setting (AudioSettings); every call is fire-and-
// forget and safe on devices without a vibrator (the platform call is a
// no-op there).
import 'package:flutter/services.dart';

import '../audio/audio_service.dart';

class Haptics {
  Haptics._();

  static bool get _on => AudioService.instance?.settings.haptics ?? false;

  static void light() {
    if (_on) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_on) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_on) HapticFeedback.heavyImpact();
  }
}
