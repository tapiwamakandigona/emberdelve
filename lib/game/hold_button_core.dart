// game/hold_button_core.dart — pointer-state machine for HUD hold buttons.
// Pure Dart, unit-tested.
//
// Why this exists (alpha.1 movement bug): Flame's TapCallbacks ride on
// Flutter's MultiTapGestureRecognizer. The moment a held thumb drifts past
// the platform touch slop (~8-18 px), the gesture arena rejects the tap
// (onTapCancel) and promotes the pointer to a drag. A hold button that
// releases on tapCancel therefore drops held movement almost immediately on
// real devices — while instant taps (jump/attack) and synthetic test taps
// keep working. The fix: a button is "pressed" while ANY pointer that
// started on it is still down, whether the arena calls it a tap or a drag.
//
// Arena ordering detail: Flutter rejects the losing tap BEFORE accepting the
// winning drag (GestureArenaManager._resolveInFavorOf), so tapCancel arrives
// before the matching dragStart, synchronously in the same call stack. A
// cancelled pointer is parked in a limbo set instead of released; the
// dragStart that follows reclaims it seamlessly (no release/press flicker,
// no double-fired edge actions). If no dragStart arrives — a genuine cancel,
// e.g. the app backgrounding — the next frame's [tick] releases it.
class HoldButtonCore {
  final void Function() onPressed;
  final void Function() onReleased;
  HoldButtonCore({required this.onPressed, required this.onReleased});

  final Set<int> _tapPointers = {};
  final Set<int> _dragPointers = {};
  final Set<int> _limbo = {};
  bool _pressed = false;

  bool get pressed => _pressed;

  void tapDown(int pointerId) {
    _tapPointers.add(pointerId);
    _sync();
  }

  void tapUp(int pointerId) {
    _tapPointers.remove(pointerId);
    _limbo.remove(pointerId);
    _sync();
  }

  /// Park the pointer: an arena drag-takeover sends the matching dragStart
  /// synchronously after this; only [tick] releases pointers left behind.
  void tapCancel(int pointerId) {
    if (_tapPointers.remove(pointerId)) _limbo.add(pointerId);
    _sync();
  }

  void dragStart(int pointerId) {
    _limbo.remove(pointerId);
    _dragPointers.add(pointerId);
    _sync();
  }

  void dragEnd(int pointerId) {
    _dragPointers.remove(pointerId);
    _limbo.remove(pointerId);
    _sync();
  }

  void dragCancel(int pointerId) => dragEnd(pointerId);

  /// Call once per frame: releases pointers whose tap was cancelled without
  /// a drag ever claiming them (arena hand-offs resolve within one frame).
  void tick() {
    if (_limbo.isEmpty) return;
    _limbo.clear();
    _sync();
  }

  void _sync() {
    final now =
        _tapPointers.isNotEmpty || _dragPointers.isNotEmpty || _limbo.isNotEmpty;
    if (now == _pressed) return;
    _pressed = now;
    now ? onPressed() : onReleased();
  }
}
