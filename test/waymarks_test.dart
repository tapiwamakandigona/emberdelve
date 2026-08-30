// test/waymarks_test.dart — v0.39.0 The Waymarks: the run summary surfaces
// the ledger's "so close" resolver (meta/achievements.dart
// nearestAchievements — tested since v0.5.0, shown nowhere until now) as one
// quiet panel of up to two unearned marks the player has already started.
//
// Pins:
//   1. Fresh profile, easy WIN → panel present; its rows are EXACTLY
//      nearestAchievements(meta, limit: 2) in order, and each count text is
//      the REAL statValue (§Ethics honesty — a shown number can never lie).
//   2. Easy LOSS → panel still present (recognition facts are equally true
//      after a death; this is not a "do better" prod, spec §5) — same
//      exactness pin.
//   3. Everything-earned profile → panel absent (nothing within reach means
//      nothing is said).
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 1 wins on easy; seed 18 loses on easy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart' as ach;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Bot-play [c] to a terminal phase, then outlast the terminal-hold
/// choreography so the summary is fully settled.
Future<void> playOut(WidgetTester tester, GameController c) async {
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(
    {'run_won', 'run_lost'}.contains(c.phase),
    isTrue,
    reason: 'bot must reach a terminal phase (guard=$guard)',
  );
  await pumpFor(tester, 2500);
}

/// Assert the waymarks panel shows EXACTLY nearestAchievements(meta, 2):
/// same ids, same order, and each trailing count is the real statValue.
Future<void> expectWaymarksMatch(WidgetTester tester, GameController c) async {
  final near = ach.nearestAchievements(c.meta, limit: 2);
  expect(
    near,
    isNotEmpty,
    reason: 'a profile with exactly one finished run must have started goals',
  );
  final panel = find.byKey(const ValueKey('waymarks'));
  await tester.scrollUntilVisible(panel, -200);
  expect(panel, findsOneWidget);
  for (final def in near) {
    final row = find.byKey(ValueKey('waymark-${def.id}'));
    expect(row, findsOneWidget, reason: 'row for ${def.id}');
    final count = ach.statValue(c.meta, def.stat, def.param);
    expect(
      find.descendant(of: row, matching: find.text('$count of ${def.target}')),
      findsOneWidget,
      reason: '${def.id} must show the real banked count',
    );
    expect(
      find.descendant(of: row, matching: find.text(def.name)),
      findsOneWidget,
    );
  }
  // No rows beyond the resolver's picks.
  for (final id in achievementsOrder) {
    if (near.any((d) => d.id == id)) continue;
    expect(find.byKey(ValueKey('waymark-$id')), findsNothing);
  }
}

void main() {
  testWidgets('easy win: waymarks panel mirrors nearestAchievements exactly', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    await expectWaymarksMatch(tester, c);
  });

  testWidgets('easy loss: waymarks still speak (recognition, not a prod)', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    await expectWaymarksMatch(tester, c);
  });

  testWidgets('everything earned: the panel says nothing at all', (
    tester,
  ) async {
    final c = GameController();
    // Max out every counter the ledger reads BEFORE the run (test lesson:
    // set unlocking counters before pumping the screen). The run-end bank
    // only increments, so everything stays earned at the summary.
    final m = c.meta;
    m.runsPlayed = 999;
    m.runsWon = 999;
    m.exactKills = 999;
    m.bestExactStreak = 999;
    m.lifetimeEmbers = 999999;
    m.bestAscension = 20;
    m.bestFloor = 99;
    m.dailiesPlayed = 999;
    m.winsNoRest = 999;
    m.hardWins = 999;
    m.tempersSet = 999;
    m.weeklyRulesWon.addAll({
      'all_d4',
      'elites_only',
      'no_shops',
      'short_road',
      'no_rests',
      'no_rests+no_shops',
    });
    for (final id in characters.keys) {
      m.charWins[id] = 999;
      m.charHardWins[id] = 999;
      m.unlockedCharacters.add(id);
    }
    m.bossesBeaten.addAll([
      'ember_tyrant',
      'ashen_colossus',
      'pyre_matriarch',
      'cinder_hierophant',
      'the_bellows',
      'ashfall_twins',
    ]);
    m.ownedThemes.addAll(hearthThemes.keys);
    // v0.107.0 The Unwritten Feats
    m.weekliesPlayed = 999;
    // v0.113.0 The Cold Honors
    m.doubledWins = 999;
    m.ownedCodex.addAll([for (final e in codexEntries) e.id]);
    m.hearthTalesHeard = 999;
    m.settledFoes.add('quench_hag');
    m.enemyFelled.addAll({for (final id in enemies.keys) id: 9});
    // Keep the earned-toast choreography out of the summary.
    m.seenAchievements.addAll(achievementsOrder);
    for (final id in achievementsOrder) {
      expect(
        ach.isEarned(m, achievements[id]!),
        isTrue,
        reason: 'test setup must max out $id — new stat needs a line above',
      );
    }
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(find.byKey(const ValueKey('waymarks')), findsNothing);
  });
}
