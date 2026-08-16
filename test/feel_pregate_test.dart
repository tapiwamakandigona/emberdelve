// test/feel_pregate_test.dart — legacy-feel pre-gate slice (LFP-3/5/6).
//
// Covers the docs/legacy-feel-plan.md items shipped before the ~2026-08-07
// production gate: the boon RECOMMENDED default (LFP-6c), the status-vs-
// intent separation + long-press tooltip (LFP-3), and the tap-to-fast-forward
// resolution pacing (LFP-5, incl. its "≥40% faster to input" DoD).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:emberdelve/game/tips.dart';

/// Pump frames for roughly [ms] of animation time without waiting to settle
/// (the screens run ambient loops that never settle — same helper as
/// widget_test.dart).
Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Walk the map until a fight starts (pattern shared with widget_test.dart).
Future<bool> walkIntoFight(WidgetTester tester, GameController c) async {
  final map = c.state!['map'] as Map;
  final edges = (map['edges'] as Map).cast<String, List>();
  var guard = 0;
  while (c.phase == 'map' && guard++ < 10) {
    final position = (c.state!['map'] as Map)['position'] as int;
    final next = (edges['$position'] as List).cast<int>().first;
    c.apply({'type': 'choose_node', 'node': next});
    await pumpFor(tester, 500);
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
    await pumpFor(tester, 500);
  }
  return c.phase == 'player_turn';
}

void main() {
  group('LFP-6c boon RECOMMENDED default', () {
    test('die boons outrank stat boons; bigger die wins', () {
      // keen_start grants a d6 — beats gold and max-HP boons.
      expect(
        BoonScreen.recommendedIndex([
          'ember_purse',
          'stout_heart',
          'keen_start',
        ]),
        equals(2),
      );
      // No die boon: max HP outranks gold.
      expect(
        BoonScreen.recommendedIndex(['ember_purse', 'stout_heart']),
        equals(1),
      );
      // Deterministic: same input, same answer, first card wins exact ties.
      expect(
        BoonScreen.recommendedIndex(['keen_start', 'keen_start']),
        equals(0),
      );
      expect(BoonScreen.recommendedIndex(const []), equals(-1));
    });

    testWidgets('boon screen renders exactly one RECOMMENDED chip', (
      tester,
    ) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      c.startRun(character: 'kindler', boons: true, seed: 1);
      await pumpFor(tester, 700);
      expect(c.phase, equals('boon'));
      expect(find.text('RECOMMENDED'), findsOneWidget);
      await pumpFor(tester, 800); // drain animations before teardown
    });
  });

  group('LFP-3 status vs intent', () {
    testWidgets('burn renders as a status chip, not inside the intent row; '
        'long-press explains it', (tester) async {
      final c = GameController();
      c.meta.tutorialSeen = true;
      c.meta.tipsSeen.addAll(ContextTips.all);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      c.startRun(character: 'kindler', seed: 1);
      await pumpFor(tester, 400);
      if (!await walkIntoFight(tester, c)) return; // no early fight; fine
      c.sim!.enemy!['burn'] = 3;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 2400); // outlast the name-plate splash

      final chip = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_StatusChip',
      );
      final badge = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_IntentBadge',
      );
      expect(chip, findsOneWidget);
      expect(badge, findsOneWidget);
      // Separation: the status chip sits clearly BELOW the intent badge —
      // they no longer read as one row ("shield 13, burn you for 3").
      final chipRect = tester.getRect(chip);
      final badgeRect = tester.getRect(badge);
      expect(
        chipRect.top >= badgeRect.bottom,
        isTrue,
        reason: 'status chip $chipRect must sit below intent badge $badgeRect',
      );
      // LFP-3b: long-press names the stack in a call-out.
      await tester.longPress(chip);
      await pumpFor(tester, 300);
      expect(find.textContaining('BURN 3'), findsOneWidget);
      await pumpFor(tester, 2400); // drain the call-out before teardown
    });
  });

  group('LFP-2a assignment preview', () {
    test('preview matches the sim die_assigned value across whole runs', () {
      // Drift guard: assignPreview is a presentation-side twin of the sim's
      // assign math. Replay scripted runs on several seeds and assert the
      // preview equals the sim's own resolved value for EVERY assignment.
      var checked = 0;
      for (final seed in [1, 2, 3, 7, 11, 42, 99, 1234, 424242, 1842571558]) {
        final sim = Sim(seed);
        sim.apply({'type': 'start_run', 'character': 'kindler'});
        var guard = 0;
        while (sim.phase != 'run_won' &&
            sim.phase != 'run_lost' &&
            guard++ < 400) {
          switch (sim.phase) {
            case 'map':
              final map = sim.state()['map'] as Map;
              final edges = (map['edges'] as Map).cast<String, List>();
              final next = (edges['${map['position']}'] as List)
                  .cast<int>()
                  .first;
              sim.apply({'type': 'choose_node', 'node': next});
              break;
            case 'player_turn':
              final player = sim.state()['player'] as Map;
              final enemy = sim.state()['enemy'] as Map;
              if (player['rolled'] == null) {
                sim.apply({'type': 'roll'});
                break;
              }
              final rolled = (player['rolled'] as List).cast<int>();
              final assigned = (player['assigned'] as Map);
              final run = sim.state()['run'] as Map?;
              var acted = false;
              for (var d = 1; d <= rolled.length; d++) {
                if (assigned['$d'] != null) continue;
                // Alternate actions so both formulas stay covered.
                final action = d.isEven ? 'block' : 'attack';
                final expected = assignPreview(player, enemy, run, d, action);
                final events = sim.apply({
                  'type': 'assign',
                  'die': d,
                  'action': action,
                });
                final da = events
                    .where((e) => e['type'] == 'die_assigned')
                    .toList();
                if (expected < 0) {
                  expect(
                    da,
                    isEmpty,
                    reason:
                        'seed $seed die $d $action: preview said '
                        'invalid but the sim assigned',
                  );
                } else {
                  expect(
                    da,
                    isNotEmpty,
                    reason:
                        'seed $seed die $d $action: preview said '
                        '$expected but the sim rejected',
                  );
                  expect(
                    da.first['value'],
                    equals(expected),
                    reason: 'seed $seed die $d $action drifted',
                  );
                  checked++;
                }
                acted = true;
                break; // state changed (combos/kill) — recompute
              }
              if (!acted) sim.apply({'type': 'end_turn'});
              break;
            case 'reward':
              sim.apply({'type': 'choose_reward', 'index': 1});
              break;
            case 'rest':
              sim.apply({'type': 'rest'});
              break;
            case 'shop':
              sim.apply({'type': 'leave_shop'});
              break;
            case 'event':
              sim.apply({'type': 'event_choose', 'option': 1});
              break;
            default:
              guard = 400;
          }
        }
      }
      // The guard is only meaningful if it actually checked assignments.
      expect(checked, greaterThan(80));
    });
  });

  group('LFP-5 resolution fast-forward', () {
    testWidgets('tapping during enemy resolution reaches input ≥40% faster', (
      tester,
    ) async {
      final c = GameController();
      c.meta.tutorialSeen = true;
      c.meta.tipsSeen.addAll(ContextTips.all);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      c.startRun(character: 'kindler', seed: 1);
      await pumpFor(tester, 400);
      if (!await walkIntoFight(tester, c)) return; // no early fight; fine
      // Pin the fight so neither side can die during the measurement, and
      // force a plain attack intent so both turns resolve the same path.
      final enemy = c.sim!.enemy!;
      enemy['hp'] = 999;
      enemy['max_hp'] = 999;
      enemy['pattern'] = [
        {'kind': 'attack', 'amount': 3},
      ];
      enemy['pattern_index'] = 1;
      enemy['intent'] = {'kind': 'attack', 'amount': 3};
      c.sim!.player['hp'] = 99;
      c.sim!.player['max_hp'] = 99;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 2400); // outlast a possible name-plate splash

      // "Reached input" = the Roll button is ENABLED again (it renders
      // immediately after end_turn but stays disabled while the resolution
      // choreography holds _busy).
      bool rollEnabled() {
        final btns = tester.widgetList<EmberButton>(
          find.byWidgetPredicate((w) => w is EmberButton && w.label == 'Roll'),
        );
        return btns.isNotEmpty && btns.first.onTap != null;
      }

      // One END TURN → next-input round trip, in pumped milliseconds.
      Future<int> endTurnMs({required bool fastForward}) async {
        expect(rollEnabled(), isTrue);
        await tester.tap(find.text('Roll'));
        await pumpFor(tester, 900); // tumble cascade
        await tester.tap(find.text('End turn'));
        var ms = 0;
        const step = 50;
        while (ms < 8000) {
          await tester.pump(const Duration(milliseconds: step));
          ms += step;
          if (fastForward && (ms == 100 || ms == 150)) {
            // Tap the stage (empty area under the enemy header) twice:
            // 2x, then skip-to-state.
            final size =
                tester.view.physicalSize / tester.view.devicePixelRatio;
            await tester.tapAt(Offset(size.width / 2, size.height * 0.42));
          }
          if (rollEnabled()) return ms;
        }
        fail('enemy resolution never returned to input');
      }

      final normal = await endTurnMs(fastForward: false);
      final fast = await endTurnMs(fastForward: true);
      expect(
        fast <= normal * 0.6,
        isTrue,
        reason:
            'fast-forwarded turn ($fast ms) must be ≥40% faster than '
            'full choreography ($normal ms)',
      );
      await pumpFor(tester, 2400); // drain call-outs before teardown
    });
  });
}
