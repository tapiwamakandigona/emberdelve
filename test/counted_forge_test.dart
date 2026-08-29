// test/counted_forge_test.dart — v0.97.0 The Counted Forge.
//
// Forge rows state what actually changes: the same dieFacts sentence the
// reward/shop/boon pickers use, before and after. Pins: the facts wording,
// exhaustiveness over every mod key in the data (a new mod can never
// silently render nothing), and the rendered before→after line at a fire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
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
  test('dieFacts wording pins', () {
    expect(dieFacts(dieDef('d6')), 'd6');
    expect(dieFacts(dieDef('d6_keen')), 'd6 · +1 attack');
    expect(dieFacts(dieDef('d6_steady')), 'd6 · min 3');
    expect(dieFacts(dieDef('d4_lucky')), 'd4 · +3 on max');
    expect(dieFacts(dieDef('d8_aegis')), 'd8 · +2 block · block only');
    expect(dieFacts(dieDef('d6_brand')), 'd6 · +2 attack · attack only');
    expect(dieFacts(dieDef('d6_forged')), 'd6 · +1 attack · +1 block');
  });

  test('every mod key in the data renders as a fact', () {
    const handled = {
      'attack_bonus',
      'block_bonus',
      'min_value',
      'on_max_bonus',
      'attack_only',
      'block_only',
    };
    for (final id in diceOrder) {
      final d = dieDef(id);
      for (final key in d.mods.keys) {
        expect(handled, contains(key), reason: '$id mod "$key" unrendered');
      }
      expect(dieFacts(d), startsWith('d${d.size}'));
      // A modded die must say more than its size — silence is dishonest.
      if (d.mods.isNotEmpty) expect(dieFacts(d), contains('·'), reason: id);
    }
  });

  testWidgets('modded forge rows print before → after facts', (tester) async {
    final c = atRest();
    // Force a modded die into slot 1 so the facts line has something the
    // chip labels do not already say.
    ((c.state!['player'] as Map)['dice'] as List)[0] = 'd6_keen';
    final into = dieDef(dieDef('d6_keen').forgeTo.first);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 600);
    final line = tester
        .widget<Text>(find.byKey(const ValueKey('forge-facts-1')))
        .data!;
    expect(line, '${dieFacts(dieDef('d6_keen'))}  →  ${dieFacts(into)}');
  });

  testWidgets('plain size-only forges stay quiet', (tester) async {
    final c = atRest();
    // Force a plain pool: d6 → d8 is fully counted by the chips' own
    // labels, so the restraint rule shows no facts line at all.
    final pool = (c.state!['player'] as Map)['dice'] as List;
    for (var i = 0; i < pool.length; i++) {
      pool[i] = 'd6';
    }
    ((c.state!['run'] as Map)['custom_dice'] as Map?)?.clear();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 600);
    final factFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.key != null &&
          w.key.toString().contains('forge-facts-'),
    );
    expect(factFinder, findsNothing);
  });
}
