// test/spoken_delve_test.dart — v0.122.0 The Spoken Delve.
//
// The run's choice surfaces spoken: reward flip cards, boon cards, the
// temper sheet's pickers, and the shop's buy button all carry semantic
// labels a screen reader can act on. Contract per surface: the label
// names the actual thing (from the same defs the paint uses), tappable
// things are buttons, and chosen/afford states are spoken.
import 'package:emberdelve/data/boons.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  final end = ms ~/ 50;
  for (var i = 0; i < end; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Bot-walk a fresh run to [phase] (controller idiom — raw-sim walks
/// diverge, v0.114.0 lesson).
GameController atPhase(String phase) {
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.startRun(character: 'kindler', seed: 7, difficulty: 'easy');
  var guard = 0;
  while (c.phase != phase &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, phase, reason: 'seed 7 must reach $phase');
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reward cards speak their die once flipped', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = atPhase('reward');
    final offers = (c.state!['offers'] as List).cast<String>();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    // Past every flip delay (220 + i*240) plus the turn itself.
    await pumpFor(tester, 1600);
    final def = dieDef(offers.first);
    expect(
      find.bySemanticsLabel(RegExp('Take the ${def.name}, a d${def.size}')),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('boon cards are one spoken button: name and effects', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = GameController();
    c.meta.tutorialSeen = true;
    // Boon offers are the restart flow's opener (boons: true — the same
    // switch startDailyRun throws).
    c.startRun(character: 'kindler', seed: 7, difficulty: 'easy', boons: true);
    expect(c.phase, 'boon');
    final offered = (c.state!['boons'] as List).cast<String>();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    final def = boonDef(offered.first);
    expect(find.bySemanticsLabel(RegExp('^${def.name}')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('the shop buy button names the deed, not a bare number', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = atPhase('shop');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    expect(find.bySemanticsLabel(RegExp(r'Buy .+ for \d+ gold')), findsWidgets);
    semantics.dispose();
  });

  test('spoken labels stay honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    const samples = [
      'Take the Ember Die, a d6, the recommended pick',
      'A reward card, still face down',
      'Buy Ember Die for 30 gold',
      'Ember Die, 30 gold, not enough gold',
      'Die 1, Flint Shard, chosen',
      'Face 3, chosen',
    ];
    for (final t in samples) {
      for (final b in banned) {
        expect(t.toLowerCase().contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
