// test/boss_kill_moment_test.dart — experimental polish loop, critic round 1
// issue C1-01 (+ C0-12 folded in): the run's final kill.
//
// Round-1 plates (020/039 *_run_won) were 100% flat #FFE9C4: the boss kill
// painted a full-screen opaque white-out for ≥260 ms — also under reduced
// motion — and hid the boss's death. At +1200 ms the tray and End turn were
// fully lit as if the fight went on, and "OVERKILL +3 → NEXT FOE" promised
// a foe that does not exist. This test lands a real lethal blow on a boss
// (FIXTURE: the current node and foe are marked boss and the foe's HP set so
// the die overkills) through the production controls at 360x800, rasterises
// every 40 ms frame and asserts:
//   • no frame has more than half its pixels at luma > 230 (normal motion),
//     and under reduced motion no frame has any meaningful bright share;
//   • from the blow on, End turn is disabled and the dice tray ignores taps;
//   • no NEXT FOE call-out ever shows on the run-ending kill.
// Plus unit checks of the toast selection. Nothing in lib/sim is touched.
import 'dart:typed_data';

import 'package:emberdelve/ui/kill_moment.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:emberdelve/sim/assignment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart'
    show button, loadRealFonts, makeController, toFight;

/// Share of pixels with Rec.601 luma above 230.
Future<double> brightShare(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 0.5);
      final bytes = Uint8List.sublistView((await image.toByteData())!);
      var bright = 0;
      final n = image.width * image.height;
      for (var i = 0; i < bytes.length; i += 4) {
        final y =
            0.299 * bytes[i] + 0.587 * bytes[i + 1] + 0.114 * bytes[i + 2];
        if (y > 230) bright++;
      }
      image.dispose();
      return bright / n;
    }))!;

/// True when every DieChip on screen sits under an ignoring IgnorePointer
/// (or there are none left).
bool trayInert(WidgetTester tester) {
  for (final e in find.byType(DieChip).evaluate()) {
    var ignored = false;
    e.visitAncestorElements((anc) {
      final w = anc.widget;
      if (w is IgnorePointer && w.ignoring) {
        ignored = true;
        return false;
      }
      if (w is AbsorbPointer && w.absorbing) {
        ignored = true;
        return false;
      }
      return true;
    });
    if (!ignored) return false;
  }
  return true;
}

Future<void> bossKill(WidgetTester tester, {required bool reduced}) async {
  const size = Size(360, 800);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: reduced ? 'on' : 'off');
  await tester.runAsync(warmSpriteSheets);
  final c = makeController();
  final shot = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    ),
  );
  await toFight(tester, c);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final rolled = (c.sim!.player['rolled'] as List).length;
  var die = 0, value = 0;
  for (var d = 1; d <= rolled; d++) {
    final r = resolveAssignment(
      player: c.sim!.player,
      enemy: c.sim!.enemy!,
      run: c.sim!.run,
      die: d,
      action: 'attack',
    );
    if (r.allowed && r.value >= 2) {
      die = d;
      value = r.value;
      break;
    }
  }
  expect(die, greaterThan(0), reason: 'seed 1 must roll an attack die ≥ 2');
  // FIXTURE: this node is the boss's and the foe dies to the die with
  // surplus (an overkill) — the run-ending blow.
  final map = c.sim!.map!;
  ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
  c.sim!.enemy!['boss'] = true;
  c.sim!.enemy!['hp'] = value - 1;
  c.sim!.enemy!['block'] = 0;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
  await tester.tap(dice.at(die - 1));
  await tester.pump();
  await tester.tap(button('Attack'));

  final problems = <String>[];
  var frames = 0;
  var peak = 0.0;
  var sawRunWon = false;
  for (var ms = 40; ms <= 2400; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    if (c.phase == 'run_won') sawRunWon = true;
    if (find.byType(CombatScreen).evaluate().isEmpty) break;
    frames++;
    final share = await brightShare(tester, shot);
    if (share > peak) peak = share;
    final limit = reduced ? 0.02 : 0.5;
    if (share > limit) {
      problems.add(
        't=${ms}ms  ${(share * 100).toStringAsFixed(1)}% of pixels at '
        'luma>230 (limit ${(limit * 100).toStringAsFixed(0)}%)',
      );
    }
    if (ms >= 80) {
      if (button('End turn').evaluate().isNotEmpty) {
        problems.add('t=${ms}ms  End turn is still live after the kill');
      }
      if (!trayInert(tester)) {
        problems.add(
          't=${ms}ms  the dice tray still takes taps after the kill',
        );
      }
    }
    if (find.textContaining('NEXT FOE').evaluate().isNotEmpty) {
      problems.add('t=${ms}ms  NEXT FOE call-out on the run-ending kill');
    }
  }
  expect(sawRunWon, isTrue, reason: 'the fixture blow ends the run');
  expect(frames, greaterThan(20), reason: 'the kill moment was sampled');
  expect(
    problems,
    isEmpty,
    reason:
        'peak bright share ${(peak * 100).toStringAsFixed(1)}%\n'
        '${problems.take(12).join('\n')}',
  );
}

void main() {
  setUpAll(loadRealFonts);

  group('overkillCallout (C0-12)', () {
    test('an ordinary overkill promises the next foe', () {
      expect(
        overkillCallout([
          {'type': 'damage_dealt', 'amount': 9},
          {'type': 'overkill', 'surplus': 3},
          {'type': 'encounter_won'},
        ]),
        'OVERKILL +3 → NEXT FOE',
      );
    });
    test('a run-ending overkill has no next foe to promise', () {
      expect(
        overkillCallout([
          {'type': 'overkill', 'surplus': 3},
          {'type': 'encounter_won'},
          {'type': 'run_won'},
        ]),
        isNull,
      );
      expect(
        overkillCallout([
          {'type': 'overkill', 'surplus': 3},
        ], bossKill: true),
        isNull,
      );
    });
    test('no overkill, no call-out', () {
      expect(
        overkillCallout([
          {'type': 'exact_kill'},
        ]),
        isNull,
      );
    });
  });

  test('encounterEnds reads both outcomes', () {
    expect(
      encounterEnds([
        {'type': 'encounter_won'},
      ]),
      isTrue,
    );
    expect(
      encounterEnds([
        {'type': 'encounter_lost'},
      ]),
      isTrue,
    );
    expect(
      encounterEnds([
        {'type': 'damage_dealt'},
      ]),
      isFalse,
    );
  });

  testWidgets('boss kill: no white-out, board goes inert, no NEXT FOE', (
    t,
  ) async {
    await bossKill(t, reduced: false);
  });
  testWidgets('boss kill under reduced motion: no bright flash at all', (
    t,
  ) async {
    await bossKill(t, reduced: true);
  });
}
