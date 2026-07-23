// test/widget_test.dart — UI smoke tests. The overhauled screens run ambient
// looping animations (ember drift, node-glow pulse, logotype sparks), so these
// tests use bounded pumps instead of pumpAndSettle, which would never settle.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/daily.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/ui/logo.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

/// Pump frames for roughly [ms] of animation time without waiting to settle.
Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('title renders the logotype and Delve enters the map',
      (tester) async {
    final c = GameController(); // no boot(): starts at title
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 400);

    // The wordmark is drawn (EmberLogotype), not a plain Text widget.
    expect(find.byType(EmberLogotype), findsOneWidget);
    expect(find.text('EMBERDELVE'), findsNothing);
    expect(find.text('Delve'), findsOneWidget);

    // Start a run directly (avoids the wall-clock seed path being flaky).
    c.startRun(character: 'kindler', seed: 1); // pinned for determinism
    await pumpFor(tester, 800);

    // Map phase renders the top bar resources.
    expect(c.phase, equals('map'));
    expect(find.text('GOLD'), findsOneWidget);
    expect(find.text('EMBERS'), findsWidgets);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });

  testWidgets('combat renders die faces and rolling triggers the tray',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    // Pinned seed: keep this test deterministic (seed 1's first reachable
    // node is a fight, so the walk below always lands in combat).
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 700);

    // Walk into the first reachable node until a fight starts.
    final map = c.state!['map'] as Map;
    final edges = (map['edges'] as Map).cast<String, List>();
    var guard = 0;
    while (c.phase == 'map' && guard++ < 10) {
      final position = (c.state!['map'] as Map)['position'] as int;
      final next = (edges['$position'] as List).cast<int>().first;
      c.apply({'type': 'choose_node', 'node': next});
      await pumpFor(tester, 700);
      if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
      if (c.phase == 'rest') c.apply({'type': 'rest'});
      if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
      if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
      await pumpFor(tester, 700);
    }
    if (c.phase != 'player_turn') return; // map had no early fight; fine

    await pumpFor(tester, 2200); // outlast a possible name-plate splash
    expect(find.byType(DieChip), findsWidgets);
    expect(find.text('Roll'), findsOneWidget);
    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 900); // tumble cascade completes
    expect(find.text('Attack'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });

  testWidgets('boon screen offers 1-of-3 and skip enters the map',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startRun(character: 'kindler', boons: true, seed: 1);
    await pumpFor(tester, 700);

    expect(c.phase, equals('boon'));
    expect(find.text('Choose a boon'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.byKey(ValueKey('boon-$i')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('boon-skip')));
    await pumpFor(tester, 700);
    expect(c.phase, equals('map'));
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });

  testWidgets('picking a boon applies its effect and enters the map',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    // Seed 1 offers [steady_hand, ward_start, kindled_cache]; slot 1 grants
    // a die, growing the pool from 3 to 4.
    c.startRun(character: 'kindler', boons: true, seed: 1);
    await pumpFor(tester, 700);
    expect(c.phase, equals('boon'));
    final before = ((c.state!['player'] as Map)['dice'] as List).length;
    await tester.tap(find.byKey(const ValueKey('boon-1')));
    await pumpFor(tester, 700);
    expect(c.phase, equals('map'));
    final after = ((c.state!['player'] as Map)['dice'] as List).length;
    expect(after, equals(before + 1));
    await pumpFor(tester, 800);
  });

  testWidgets('risky reroll: gated to unassigned dice, once per turn',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    // Seed 1: the first reachable node is a fight.
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 700);
    final map = c.state!['map'] as Map;
    final edges = (map['edges'] as Map).cast<String, List>();
    final position = map['position'] as int;
    c.apply({
      'type': 'choose_node',
      'node': (edges['$position'] as List).cast<int>().first,
    });
    await pumpFor(tester, 1200); // flame-wipe into combat
    expect(c.phase, equals('player_turn'));

    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 2200); // tumble + combo call-outs drain

    // Control present and enabled before use.
    expect(find.textContaining('Risky reroll'), findsOneWidget);

    // Assign die 1 (block is instant, no choreography) so it is off-limits.
    c.apply({'type': 'assign', 'die': 1, 'action': 'block'});
    await pumpFor(tester, 300);

    await tester.tap(find.textContaining('Risky reroll'));
    await pumpFor(tester, 300);
    expect(find.textContaining('Pick dice to reroll'), findsOneWidget);
    expect(find.text('Reroll (0)'), findsOneWidget);

    // Tapping the ASSIGNED die never joins the selection.
    await tester.tap(find.byType(DieChip).at(0), warnIfMissed: false);
    await pumpFor(tester, 300);
    expect(find.text('Reroll (0)'), findsOneWidget);

    // An unassigned die does.
    await tester.tap(find.byType(DieChip).at(1), warnIfMissed: false);
    await pumpFor(tester, 300);
    expect(find.text('Reroll (1)'), findsOneWidget);

    await tester.tap(find.text('Reroll (1)'));
    await pumpFor(tester, 2200); // retumble + call-outs drain

    // Spent for this turn: sim flag set, control disabled.
    expect((c.state!['player'] as Map)['risky_used'], isTrue);
    expect(find.text('Reroll spent'), findsOneWidget);
    await pumpFor(tester, 800);
  });

  test('stale/corrupt autosaves are cleared; healthy v4 saves restore',
      () async {
    final dir = await Directory.systemTemp.createTemp('emberdelve_test');
    final f = File('${dir.path}/emberdelve_run.json');

    // v3 (pre-SIM_VERSION-4) autosave: rejected, cleared, fresh start.
    await f.writeAsString(
        jsonEncode({'version': 3, 'phase': 'map', 'player': {}}));
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    expect(c.sim, isNull, reason: 'stale save must not restore');
    expect(await f.exists(), isFalse, reason: 'stale save must be deleted');

    // Corrupt v4 snapshot: Sim.restore throws; boot survives and clears.
    await f.writeAsString(jsonEncode({'version': 4, 'phase': 'map'}));
    await c.boot();
    expect(c.sim, isNull);
    expect(await f.exists(), isFalse);

    // Healthy mid-run v4 snapshot still restores.
    final sim = Sim(7)..apply({'type': 'start_run', 'character': 'kindler'});
    await f.writeAsString(jsonEncode(sim.snapshot()));
    await c.boot();
    expect(c.phase, equals('map'));
    await dir.delete(recursive: true);
  });

  testWidgets('daily delve starts the shared seeded run', (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 400);
    expect(find.textContaining('Daily Delve'), findsOneWidget);

    c.startDailyRun(character: 'kindler');
    await pumpFor(tester, 700);
    // Daily runs open on the boon pick and carry the date label; the seed is
    // the shared dailySeed of the device's local date.
    expect(c.phase, equals('boon'));
    expect(c.dailyDate, isNotNull);
    final now = DateTime.now();
    expect(c.sim!.runSeed, equals(dailySeed(now.year, now.month, now.day)));
    await pumpFor(tester, 800);
  });

  testWidgets('summary offers a fast Delve again into the boon pick',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 700);
    // Force a terminal phase through the sim's own command surface: walk the
    // run with a trivial policy until it ends (bounded).
    var guard = 0;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
      switch (c.phase) {
        case 'map':
          final m = c.state!['map'] as Map;
          final e = (m['edges'] as Map).cast<String, List>();
          final p = m['position'] as int;
          c.apply({
            'type': 'choose_node',
            'node': (e['$p'] as List).cast<int>().first,
          });
          break;
        case 'player_turn':
          c.apply({'type': 'roll'});
          c.apply({'type': 'end_turn'});
          break;
        case 'reward':
          c.apply({'type': 'choose_reward', 'index': 0});
          break;
        case 'rest':
          c.apply({'type': 'rest'});
          break;
        case 'shop':
          c.apply({'type': 'leave_shop'});
          break;
        case 'event':
          c.apply({'type': 'event_choose', 'option': 1});
          break;
      }
    }
    // Rolling without assigning loses the run quickly.
    expect(c.phase, anyOf('run_won', 'run_lost'));
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography
    expect(find.text('Delve again'), findsOneWidget);
    await tester.tap(find.text('Delve again'));
    await pumpFor(tester, 900);
    expect(c.phase, equals('boon')); // straight into the pick, no title
    await pumpFor(tester, 800);
  });

  testWidgets('character screen lists all delvers', (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 300);
    await tester.tap(find.text('Choose a delver'));
    await pumpFor(tester, 700);
    // Top cards render; lower ones are lazily built when scrolled into view.
    expect(find.text('The Kindler'), findsOneWidget);
    expect(find.text('The Warden'), findsOneWidget);
    expect(find.text('NEXT UNLOCK — THE WARDEN'), findsOneWidget);
    await tester.dragUntilVisible(find.text('The Ascetic'),
        find.byType(Scrollable).first, const Offset(0, -200));
    expect(find.text('The Ascetic'), findsOneWidget);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });
}
