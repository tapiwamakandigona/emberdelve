// Regression tests for the post-encounter "progression glitches back and
// forth" bug (owner report, 2026-08-11).
//
// Root cause: PhaseSwitcher.build() returned a BARE widget.child when idle
// but an AnimatedBuilder>Stack>KeyedSubtree wrapper while transitioning. The
// tree SHAPE therefore changed both when a transition started and when it
// settled, and Flutter remounted the visible screen from scratch each time.
// On the map that meant: screen mounts at the fade midpoint, the delver walk
// (650ms) and follow-scroll (450ms) start, then the fade settles (380ms) and
// the whole screen State is discarded — both animations snap back and replay.
//
// Secondary ingredient: the map's follow-scroll always ANIMATED up from the
// bottom of the delve on arrival, so mid-run every return to the map showed
// the camera at the start of the delve sweeping back up to the delver.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/sim/autoplay.dart';
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
/// Returns seed * 100000 + node, or null. (Same probe as
/// phase_transition_test.dart.)
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
  testWidgets('arriving screen State survives the phase transition settling '
      '(no remount = no walk/scroll restart)', (tester) async {
    final packed = findSeed('event');
    expect(packed, isNotNull, reason: 'no seed with an adjacent event found');
    final seed = packed! ~/ 100000, node = packed % 100000;
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: seed);
    await pumpFor(tester, 800);
    if (c.phase == 'boon') {
      c.apply({'type': 'choose_boon', 'index': 1});
      await pumpFor(tester, 800);
    }
    c.apply({'type': 'choose_node', 'node': node});
    await pumpFor(tester, 800);
    expect(c.phase, 'event');
    c.apply({'type': 'event_choose', 'option': 1});
    // The fade back to the map runs 380ms and mounts the map at its midpoint.
    // Grab the State mid-transition, then again after it settles: it must be
    // the SAME State object, or the delver walk + follow scroll restart and
    // the progression visibly jumps back and forth.
    await pumpFor(tester, 250);
    expect(c.phase, 'map');
    final s1 = tester.state(find.byType(MapScreen));
    await pumpFor(tester, 600);
    final s2 = tester.state(find.byType(MapScreen));
    expect(
      identical(s1, s2),
      isTrue,
      reason:
          'PhaseSwitcher remounted the arriving screen when the '
          'transition settled — the delver walk and follow scroll restart '
          'mid-flight (the "progression glitches back and forth" bug)',
    );
  });

  testWidgets('map arrival frames the delver instantly (no bottom-up sweep)', (
    tester,
  ) async {
    // Drive the greedy bot to a mid-run map (delver on layer >= 4) so the
    // follow target sits meaningfully above the bottom of the delve.
    GameController? mid;
    for (var seed = 1; seed <= 40 && mid == null; seed++) {
      final c = GameController();
      // Camera-in-isolation: pre-seed all tips so the v0.30.0 whats_a_delve
      // card (its own Scrollable) doesn't stack a second scrollable here.
      c.meta.tipsSeen.addAll(ContextTips.all);
      c.startRun(character: 'kindler', seed: seed);
      var guard = 0;
      while (guard++ < 600 && c.phase != 'run_won' && c.phase != 'run_lost') {
        if (c.phase == 'map') {
          final map = c.state!['map'] as Map;
          final pos = map['position'] as int;
          final layer = ((map['nodes'] as Map)['$pos'] as Map)['layer'] as int;
          if (layer >= 4) {
            mid = c;
            break;
          }
        }
        final cmd = botCmd(c.sim!, character: 'kindler');
        if (cmd == null) break;
        c.apply(cmd);
      }
    }
    expect(
      mid,
      isNotNull,
      reason: 'no bot run reached map layer 4 in 40 seeds',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Scaffold(body: MapScreen(mid!)),
      ),
    );
    // First frame schedules the follow; the post-frame callback must JUMP the
    // camera onto the delver, not start a 450ms sweep from the delve floor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final early = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    await pumpFor(tester, 700);
    final settled = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(
      early,
      greaterThan(0),
      reason: 'mid-run arrival should already be framed above the floor',
    );
    expect(
      early,
      settled,
      reason:
          'camera moved after arrival — the map is still sweeping up '
          'from the bottom of the delve on every visit',
    );
  });
}
