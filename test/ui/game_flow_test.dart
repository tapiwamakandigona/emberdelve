// Widget tests for the Emberdelve UI: boot routing, map interaction, combat
// flow, reward/rest/summary screens, autosave + resume, and die-mod button
// gating. Runs against the REAL Sim (no mocks) with fixed seeds.
import 'dart:convert';

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/main.dart';
import 'package:emberdelve/services/session.dart';
import 'package:emberdelve/ui/screens/combat_screen.dart';
import 'package:emberdelve/ui/screens/map_screen.dart';
import 'package:emberdelve/ui/screens/rest_screen.dart';
import 'package:emberdelve/ui/screens/summary_screen.dart';
import 'package:emberdelve/ui/screens/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Greedy drive policy — same shape as tool/parity/gen_fixtures.lua
/// next_cmd; used here only to push a run forward through real phases.
Map<String, dynamic>? botCmd(GameSession session) {
  final st = session.state;
  final phase = st['phase'] as String;
  if (phase == 'idle') return {'type': 'start_run'};
  if (phase == 'map') {
    final map = st['map'] as Map<String, dynamic>;
    final edges = ((map['edges'] as Map)[map['position']] as List).cast<int>();
    return {'type': 'choose_node', 'node': edges.first};
  }
  if (phase == 'player_turn') {
    final player = st['player'] as Map<String, dynamic>;
    final rolled = player['rolled'] as List?;
    if (rolled == null) return {'type': 'roll'};
    final assigned = player['assigned'] as Map;
    for (var i = 1; i <= rolled.length; i++) {
      if (!assigned.containsKey(i)) {
        final mods =
            (diceData[(player['dice'] as List)[i - 1]]!['mods']) as Map;
        return {
          'type': 'assign',
          'die': i,
          'action': mods['block_only'] == true ? 'block' : 'attack',
        };
      }
    }
    return {'type': 'end_turn'};
  }
  if (phase == 'reward') return {'type': 'choose_reward', 'index': 0};
  if (phase == 'rest') return {'type': 'rest'};
  return null; // terminal
}

Future<GameSession> pumpApp(WidgetTester tester) async {
  final session = GameSession();
  await session.loadSaved();
  await tester.pumpWidget(EmberdelveApp(session: session));
  await tester.pumpAndSettle();
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots to Title when no save exists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.text('NEW RUN'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
  });

  testWidgets('New Run routes to Map; only reachable nodes are tappable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await pumpApp(tester);

    await tester.tap(find.text('NEW RUN'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);

    final map = session.state['map'] as Map<String, dynamic>;
    final position = map['position'] as int;
    final reachable =
        ((map['edges'] as Map)[position] as List).cast<int>();
    expect(reachable, isNotEmpty);

    // Tap the first reachable node — position must advance / phase change.
    final target = reachable.first;
    final kind = ((map['nodes'] as Map)[target] as Map)['kind'];
    await tester.tap(find.bySemanticsLabel('map node $target $kind'));
    await tester.pumpAndSettle();
    expect(session.state['map']['position'], target);
    expect(session.phase, isNot('idle'));
  });

  testWidgets('combat flow: roll, select a die, attack via buttons',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await pumpApp(tester);
    await session.newRun(seed: 7);
    // Walk the map until a fight starts (bounded).
    for (var guard = 0; guard < 10 && session.phase == 'map'; guard++) {
      await session.apply(botCmd(session)!);
    }
    expect(session.phase, 'player_turn');
    await tester.pumpAndSettle();
    expect(find.byType(CombatScreen), findsOneWidget);
    expect(find.text('ROLL'), findsOneWidget);

    await tester.tap(find.text('ROLL'));
    await tester.pumpAndSettle();
    expect(find.byType(DieChip), findsNWidgets(3)); // starter pool d6 x3

    // Before selecting a die both action buttons are disabled.
    final filled = find.byWidgetPredicate((w) => w is FilledButton);
    FilledButton attackBtn() => tester.widget<FilledButton>(
        find.ancestor(of: find.text('ATTACK'), matching: filled).first);
    expect(attackBtn().onPressed, isNull);

    await tester.tap(find.byType(DieChip).first);
    await tester.pumpAndSettle();
    expect(attackBtn().onPressed, isNotNull);

    final enemyHpBefore = session.state['enemy']['hp'] as int;
    await tester.tap(find.text('ATTACK'));
    await tester.pumpAndSettle();
    final assigned = session.state['player']['assigned'] as Map;
    expect(assigned.length, 1);
    expect(session.state['enemy']['hp'], lessThan(enemyHpBefore));
  });

  testWidgets(
      'attack_only die gates the BLOCK button (and vice versa exists)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await pumpApp(tester);
    await session.newRun(seed: 7);
    for (var guard = 0; guard < 10 && session.phase == 'map'; guard++) {
      await session.apply(botCmd(session)!);
    }
    expect(session.phase, 'player_turn');
    // Test-only arrangement: swap die 1 for the attack_only Spark Chip
    // before rolling (state() exposes live refs; production UI never does
    // this — it is the cheapest way to reach a modded-die UI state).
    (session.state['player']['dice'] as List)[0] = 'd4_spark';
    await session.apply({'type': 'roll'});
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DieChip).first); // the d4_spark
    await tester.pumpAndSettle();

    final filled = find.byWidgetPredicate((w) => w is FilledButton);
    FilledButton btn(String label) => tester.widget<FilledButton>(
        find.ancestor(of: find.text(label), matching: filled).first);
    expect(btn('BLOCK').onPressed, isNull, reason: 'attack_only blocks BLOCK');
    expect(btn('ATTACK').onPressed, isNotNull);
  });

  testWidgets(
      'full seeded run reaches Reward/Rest/Summary screens as phases change',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await pumpApp(tester);
    await session.newRun(seed: 3);
    await tester.pumpAndSettle();

    var sawReward = false;
    var sawRest = false;
    for (var guard = 0; guard < 600; guard++) {
      final cmd = botCmd(session);
      if (cmd == null) break;
      await session.apply(cmd);
      await tester.pumpAndSettle();
      switch (session.phase) {
        case 'reward':
          expect(find.byType(RewardOverlay), findsOneWidget);
          sawReward = true;
        case 'rest':
          expect(find.byType(RestScreen), findsOneWidget);
          sawRest = true;
        case 'player_turn':
          expect(find.byType(CombatScreen), findsOneWidget);
        case 'map':
          expect(find.byType(MapScreen), findsOneWidget);
      }
    }
    expect(isTerminalPhase(session.phase), isTrue,
        reason: 'run must reach a terminal phase');
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('NEW RUN'), findsOneWidget);
    expect(sawReward || sawRest, isTrue,
        reason: 'a full run visits at least one reward or rest');
  });

  testWidgets('autosave after commands; Continue resumes to the same phase',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await pumpApp(tester);
    await session.newRun(seed: 11);
    // Advance into a mid-run, non-terminal state.
    for (var i = 0; i < 5; i++) {
      final cmd = botCmd(session);
      if (cmd == null || isTerminalPhase(session.phase)) break;
      await session.apply(cmd);
    }
    await tester.pumpAndSettle();
    final phaseBefore = session.phase;
    expect(isTerminalPhase(phaseBefore), isFalse);

    // Autosave landed in prefs after every command.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(saveKey);
    expect(raw, isNotNull);
    expect((jsonDecode(raw!) as Map)['phase'], phaseBefore);

    // Fresh boot: Title offers Continue, and it restores the exact phase.
    final session2 = GameSession();
    await tester.pumpWidget(EmberdelveApp(session: session2));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(session2.phase, phaseBefore);
    expect(find.byType(TitleScreen), findsNothing);
  });
}
