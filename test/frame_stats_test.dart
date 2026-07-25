// FrameStats windowing math for the PERF_OVERLAY readout.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/components/perf_overlay.dart';

void main() {
  test('steady 60fps window: fps/avg/worst correct', () {
    final s = FrameStats();
    var closed = 0;
    for (var i = 0; i < 60; i++) {
      if (s.add(1 / 60)) closed++;
    }
    expect(closed, 1);
    expect(s.generation, 1);
    expect(s.fps, closeTo(60, 0.5));
    expect(s.avgMs, closeTo(16.67, 0.1));
    expect(s.worstMs, closeTo(16.67, 0.1));
    expect(s.overBudget, isFalse); // 16.67 is not > 16.7
  });

  test('one janky frame trips overBudget and resets next window', () {
    final s = FrameStats();
    for (var i = 0; i < 30; i++) {
      s.add(1 / 60);
    }
    s.add(0.050); // 50ms spike
    while (!s.add(1 / 60)) {}
    expect(s.worstMs, closeTo(50, 0.5));
    expect(s.overBudget, isTrue);
    // Next full window is clean again.
    while (!s.add(1 / 60)) {}
    expect(s.worstMs, closeTo(16.67, 0.1));
    expect(s.overBudget, isFalse);
  });

  test('zero/negative dt ignored', () {
    final s = FrameStats();
    expect(s.add(0), isFalse);
    expect(s.add(-1), isFalse);
    expect(s.generation, 0);
  });
}
