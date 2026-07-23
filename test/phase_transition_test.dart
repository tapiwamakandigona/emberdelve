// Regression tests for the v0.3.0 review finding F1: leaving a shop or
// resolving an event while PhaseSwitcher's cross-fade still shows the old
// screen must not crash (ShopScreen/EventScreen used to hard-cast state that
// is already null at that point). Adapted from the reviewer's probe test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Find a seed whose start node has a node of [kind] on its first edges.
/// Returns seed * 100000 + node, or null.
int? findSeed(String kind) {
  for (var seed = 1; seed < 4000; seed++) {
    final sim = Sim(seed);
    sim.apply({'type': 'start_run', 'character': 'kindler'});
    final map = sim.map!;
    final pos = map['position'] as int;
    final out = ((map['edges'] as Map)['$pos'] as List).cast<int>();
    for (final n in out) {
      final node = (map['nodes'] as Map)['$n'] as Map;
      if (node['kind'] == kind) return seed * 100000 + n;
    }
  }
  return null;
}

void main() {
  // Shops never spawn adjacent to the start node, so the shop variant guards
  // the widget directly: building ShopScreen against a state with no 'shop'
  // (exactly what the cross-fade shows right after leave_shop) must render
  // nothing instead of throwing a _TypeError.
  testWidgets('ShopScreen tolerates a state without shop data (stale frame)',
      (tester) async {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1);
    // Skip the boon offer so state is a plain map phase without 'shop'.
    if (c.phase == 'boon_offer') c.apply({'type': 'choose_boon', 'option': 0});
    expect(c.state!['shop'], isNull);
    await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: ShopScreen(c)));
    await pumpFor(tester, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolving an event during the phase transition does not crash',
      (tester) async {
    final packed = findSeed('event');
    expect(packed, isNotNull, reason: 'no seed with an adjacent event found');
    final seed = packed! ~/ 100000, node = packed % 100000;
    final c = GameController();
    await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)));
    c.startRun(character: 'kindler', seed: seed);
    await pumpFor(tester, 800);
    c.apply({'type': 'choose_node', 'node': node});
    await pumpFor(tester, 800);
    expect(c.phase, 'event');
    c.apply({'type': 'event_choose', 'option': 1});
    await pumpFor(tester, 800);
    expect(c.phase, 'map');
    await pumpFor(tester, 800);
  });
}
