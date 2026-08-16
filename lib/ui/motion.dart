// lib/ui/motion.dart — Reduce-motion resolver (v0.16.0 The Still Flame).
//
// One app-wide answer to "should the screen move right now?", read by the
// leaf FX (ShakeBox, EmberDrift, DamagePop) without context plumbing:
//
//   setting 'system' (default) -> follow the OS accessibility flag
//     (MediaQuery.disableAnimations, fed in by the MaterialApp builder).
//   setting 'on'  -> always reduced.
//   setting 'off' -> never reduced (explicit "I want the full feel").
//
// The user setting persists in AudioSettings.reduceMotion; Settings writes
// it here on change. ChangeNotifier so continuously-visible FX (the title's
// EmberDrift) react to a mid-session toggle without a route rebuild.
// Sub-100ms opacity cues (hit flashes, vignette pulses) deliberately do NOT
// consult this — they carry information and do not displace the image.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const Set<String> reduceMotionValues = {'system', 'on', 'off'};

class Motion extends ChangeNotifier {
  static final Motion instance = Motion();

  String _setting = 'system';
  bool _systemFlag = false;

  String get setting => _setting;
  bool get reduced => switch (_setting) {
    'on' => true,
    'off' => false,
    _ => _systemFlag,
  };

  /// Update either side of the answer; notifies only when [reduced] flips.
  /// Safe to call during build (the MaterialApp builder feeds the system
  /// flag from MediaQuery): a mid-build flip defers its notification to
  /// after the frame instead of mutating listeners while building.
  void update({String? setting, bool? systemFlag}) {
    final before = reduced;
    if (setting != null && reduceMotionValues.contains(setting)) {
      _setting = setting;
    }
    if (systemFlag != null) _systemFlag = systemFlag;
    if (reduced == before) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  @visibleForTesting
  void reset() {
    _setting = 'system';
    _systemFlag = false;
  }
}
