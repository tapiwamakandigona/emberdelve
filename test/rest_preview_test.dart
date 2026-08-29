// test/rest_preview_test.dart — v0.89.0 The Counted Rest.
//
// The rest button prints the exact heal instead of '30%'. The number comes
// from restHealPreview, a pure mirror of runRest's arithmetic — these tests
// pin the mirror to the wall, prove parity against the real command, and
// drive the widget to read the printed sentence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart' show restHealPreview;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms / 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pure-controller walk (bot-driven) until the run stands at a rest fire.
// v0.114.0 re-anchor: seed 3's bot path now loses before resting
// (event deck 50->53 re-rolled it); seed 6 rests, probe-proven.
GameController atRest({int seed = 6}) {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'rest' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'rest', reason: 'seed $seed never rested');
  return c;
}

void main() {
  test('preview pins: base, overheal cap, full, rest_bonus relic', () {
    final c = atRest();
    final sim = c.sim!;
    sim.run!['relics'] = <String>[];
    sim.player['max_hp'] = 30;
    sim.player['hp'] = 21;
    expect(restHealPreview(sim), 9); // floor(30*3/10)
    sim.player['hp'] = 28;
    expect(restHealPreview(sim), 2); // capped at max
    sim.player['hp'] = 30;
    expect(restHealPreview(sim), 0); // full heals nothing
    sim.run!['relics'] = <String>['bedroll'];
    sim.player['hp'] = 10;
    expect(restHealPreview(sim), 13); // 9 base + 4 bedroll
    sim.run!['relics'] = <String>['bedroll', 'hearth_kettle'];
    expect(restHealPreview(sim), 19); // bonuses stack
  });

  test('parity: the preview equals what the rest command then heals', () {
    final c = atRest();
    final sim = c.sim!;
    sim.player['max_hp'] = 30;
    sim.player['hp'] = 17;
    final promised = restHealPreview(sim);
    final before = sim.player['hp'] as int;
    c.apply({'type': 'rest'});
    expect((c.sim!.player['hp'] as int) - before, promised);
  });

  testWidgets('the rest button prints the counted heal', (tester) async {
    final c = atRest();
    c.sim!.run!['relics'] = <String>[];
    c.sim!.player['max_hp'] = 30;
    c.sim!.player['hp'] = 21;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 800);
    expect(find.text('Rest — heal 9 HP (21\u00A0to\u00A030)'), findsOneWidget);
  });

  testWidgets('at full HP the button still moves on, no zero-heal offer', (
    tester,
  ) async {
    final c = atRest();
    c.sim!.player['hp'] = c.sim!.player['max_hp'] as int;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 800);
    expect(find.text('Move on — fully rested'), findsOneWidget);
    expect(find.textContaining('Rest — heal'), findsNothing);
  });
}
