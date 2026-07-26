// game/camera_shake.dart — AKP-3e: the camera-shake budget, as pure Dart.
//
// Shake used to be a single field in ember_game.dart that jittered only the Y
// axis and fired on EVERY enemy hit. That reads as a rattling screen during
// normal play (and on a phone it reads as a bug). This holds the rules:
//   * only heavy beats ask for shake (player hurt, crit/finisher, boss beats)
//   * amplitude is capped hard (kShakeMax) no matter what asks
//   * it decays linearly and both axes move, X at 60% of Y (vertical shake is
//     less nauseating and reads better on a landscape phone)
//   * deterministic: a fixed LCG, so tests can pin the exact trace
//
// No Flame/Flutter imports so it is unit-testable headlessly.
import 'tuning.dart';

class CameraShake {
  CameraShake({int seed = 0x5EED}) : _state = seed & 0x7fffffff;

  int _state;
  double _mag = 0;
  double _offX = 0, _offY = 0;

  /// Current amplitude in px (0 when at rest).
  double get magnitude => _mag;

  /// Offsets to add to the rendered camera position (world px).
  double get offsetX => _offX;
  double get offsetY => _offY;

  bool get active => _mag > 0;

  /// Request a shake of [amplitude] px. Never stacks past [kShakeMax], and a
  /// weaker request never cuts a stronger shake short.
  void bump(double amplitude) {
    if (amplitude <= 0) return;
    if (amplitude > _mag) _mag = amplitude;
    if (_mag > kShakeMax) _mag = kShakeMax;
  }

  /// Stop instantly (respawn / level end camera snaps).
  void reset() {
    _mag = 0;
    _offX = 0;
    _offY = 0;
  }

  void update(double dt) {
    if (_mag <= 0) {
      _offX = 0;
      _offY = 0;
      return;
    }
    _mag -= kShakeDecay * dt;
    if (_mag <= 0) {
      reset();
      return;
    }
    _offY = (_next() - 0.5) * 2 * _mag;
    _offX = (_next() - 0.5) * 2 * _mag * 0.6;
  }

  /// Deterministic 0..1 (same LCG as lib/core/rng.dart's family, kept local so
  /// gameplay RNG streams are never disturbed by a visual effect).
  double _next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}
