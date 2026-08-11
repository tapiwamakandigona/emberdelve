// HoldButtonCore — regression tests for the alpha.1 movement-controls bug:
// a held D-pad thumb drifting past the touch slop made the gesture arena
// cancel the tap (and promote it to a drag), releasing the button mid-hold.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/hold_button_core.dart';

void main() {
  late int presses;
  late int releases;
  late HoldButtonCore core;

  setUp(() {
    presses = 0;
    releases = 0;
    core = HoldButtonCore(
      onPressed: () => presses++,
      onReleased: () => releases++,
    );
  });

  test('plain tap: down presses, up releases', () {
    core.tapDown(1);
    expect(core.pressed, isTrue);
    core.tapUp(1);
    expect(core.pressed, isFalse);
    expect(presses, 1);
    expect(releases, 1);
  });

  test('REGRESSION: drag takeover keeps the button held, no flicker', () {
    core.tapDown(1);
    // Thumb drifts past touch slop: arena rejects the tap first...
    core.tapCancel(1);
    expect(core.pressed, isTrue, reason: 'must not release during hand-off');
    // ...then accepts the drag, synchronously in the same frame.
    core.dragStart(1);
    core.tick(); // frame boundary
    expect(core.pressed, isTrue);
    expect(presses, 1, reason: 'no double-press on hand-off');
    expect(releases, 0, reason: 'no release/press flicker');
    // Finger finally lifts.
    core.dragEnd(1);
    expect(core.pressed, isFalse);
    expect(releases, 1);
  });

  test('genuine cancel (no drag claims the pointer) releases on next tick',
      () {
    core.tapDown(1);
    core.tapCancel(1);
    expect(core.pressed, isTrue); // still parked in limbo this frame
    core.tick();
    expect(core.pressed, isFalse);
    expect(releases, 1);
  });

  test('drag cancel releases', () {
    core.tapDown(1);
    core.tapCancel(1);
    core.dragStart(1);
    core.dragCancel(1);
    expect(core.pressed, isFalse);
  });

  test('multi-touch: button stays pressed until the last pointer lifts', () {
    core.tapDown(1);
    core.tapDown(2);
    core.tapUp(1);
    expect(core.pressed, isTrue);
    core.tapUp(2);
    expect(core.pressed, isFalse);
    expect(presses, 1);
    expect(releases, 1);
  });

  test('mixed tap + drag pointers resolve independently', () {
    core.tapDown(1);
    core.tapCancel(1);
    core.dragStart(1); // pointer 1 now a drag
    core.tapDown(2); // pointer 2 a plain tap
    core.dragEnd(1);
    expect(core.pressed, isTrue, reason: 'pointer 2 still down');
    core.tapUp(2);
    expect(core.pressed, isFalse);
  });

  test('tick with nothing in limbo is a no-op', () {
    core.tapDown(1);
    core.tick();
    core.tick();
    expect(core.pressed, isTrue);
    expect(presses, 1);
    expect(releases, 0);
  });
}
