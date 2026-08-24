// test/enemy_record_test.dart — v0.11.0 "The Delver's Ledger": per-enemy
// record (met / felled / deaths) + this run's firsts.
//
// Covers: event-driven banking in recordCombatStats, firsts capture
// (lifetime 0 -> 1 only), persistence round-trip, cloud-merge maxMap,
// resume keeping run_firsts, and an e2e bot run producing a real record.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 3000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 3000, isTrue, reason: 'bot run failed to terminate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ed_enemy_record');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() async {
    await MetaStore.save(MetaState());
    MetaStore.dirOverride = null;
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  group('banking from events', () {
    test('met / felled / deaths accrue per enemy id', () {
      final c = GameController(saveDirOverride: dir.path);
      c.recordCombatStats([
        {'type': 'encounter_started', 'enemy': 'ash_rat'},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_won', 'turns': 3},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_started', 'enemy': 'soot_shade'},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_lost', 'turns': 5},
      ]);
      expect(c.meta.enemyMet, {'ash_rat': 1, 'soot_shade': 1});
      expect(c.meta.enemyFelled, {'ash_rat': 1});
      expect(c.meta.enemyFellTo, {'soot_shade': 1});
    });

    test('firsts capture lifetime 0 -> 1 only', () {
      final c = GameController(saveDirOverride: dir.path);
      c.meta.enemyMet['ash_rat'] = 4;
      c.meta.enemyFelled['ash_rat'] = 2;
      c.recordCombatStats([
        {'type': 'encounter_started', 'enemy': 'ash_rat'},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_won', 'turns': 2},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_started', 'enemy': 'cinder_wisp'},
      ]);
      c.recordCombatStats([
        {'type': 'encounter_won', 'turns': 2},
      ]);
      // ash_rat was already known — only the wisp is a first.
      expect(c.runFirstMet, {'cinder_wisp'});
      expect(c.runFirstFelled, {'cinder_wisp'});
      expect(c.meta.enemyMet['ash_rat'], 5);
    });

    test('a fresh run clears the previous run\'s firsts', () {
      final c = GameController(saveDirOverride: dir.path);
      c.recordCombatStats([
        {'type': 'encounter_started', 'enemy': 'ash_rat'},
      ]);
      expect(c.runFirstMet, isNotEmpty);
      c.startRun(character: 'kindler', seed: 7);
      expect(c.runFirstMet, isEmpty);
      expect(c.runFirstFelled, isEmpty);
    });
  });

  group('persistence', () {
    test('enemy record maps round-trip through json', () {
      final m = MetaState(
        enemyMet: {'ash_rat': 3},
        enemyFelled: {'ash_rat': 2},
        enemyFellTo: {'kiln_tyrant': 1},
      );
      final back = MetaState.fromJson(
        Map<String, dynamic>.from(m.toJson()),
      );
      expect(back.enemyMet, m.enemyMet);
      expect(back.enemyFelled, m.enemyFelled);
      expect(back.enemyFellTo, m.enemyFellTo);
      // Empty maps write no keys.
      expect(MetaState().toJson().containsKey('enemyMet'), isFalse);
    });

    test('cloud merge takes the per-key max', () {
      final merged = mergeMetaStates(
        MetaState(enemyMet: {'a': 3, 'b': 1}, enemyFelled: {'a': 2}),
        MetaState(enemyMet: {'a': 1, 'c': 4}, enemyFellTo: {'a': 1}),
      );
      expect(merged.enemyMet, {'a': 3, 'b': 1, 'c': 4});
      expect(merged.enemyFelled, {'a': 2});
      expect(merged.enemyFellTo, {'a': 1});
    });
  });

  test('kill + resume keeps this run\'s firsts (run_firsts side channel)',
      () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1);
    // Walk to the first fight so a first sighting exists.
    var guard = 0;
    while (c.phase == 'map' && guard++ < 10) {
      final map = c.state!['map'] as Map;
      final edges = (map['edges'] as Map).cast<String, List>();
      final position = map['position'] as int;
      final next = (edges['$position'] as List).cast<int>().first;
      c.apply({'type': 'choose_node', 'node': next});
      if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
      if (c.phase == 'rest') c.apply({'type': 'rest'});
      if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
      if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
    }
    expect(c.phase, 'player_turn', reason: 'seed 1 walk reaches a fight');
    final firsts = Set<String>.from(c.runFirstMet);
    expect(firsts, isNotEmpty);
    await c.flushSaves();

    // "Kill the app": a second controller boots from the same directory.
    final c2 = GameController(saveDirOverride: dir.path);
    await c2.boot();
    expect(c2.sim, isNotNull, reason: 'mid-run save resumes');
    expect(c2.runFirstMet, firsts);
    await c2.flushSaves();
  });

  test('e2e: a full bot run banks a coherent record', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 503);
    driveToTerminal(c);
    // Every met id is a real enemy; felled + deaths never exceed met.
    expect(c.meta.enemyMet, isNotEmpty);
    for (final id in c.meta.enemyMet.keys) {
      expect(enemies.containsKey(id), isTrue, reason: 'unknown enemy $id');
    }
    var felled = 0, met = 0;
    c.meta.enemyFelled.forEach((id, n) {
      felled += n;
      expect(n <= (c.meta.enemyMet[id] ?? 0), isTrue);
    });
    c.meta.enemyMet.forEach((_, n) => met += n);
    expect(felled <= met, isTrue);
    // Firsts on a fresh profile = every distinct enemy met.
    expect(c.runFirstMet, c.meta.enemyMet.keys.toSet());
    await c.flushSaves();
  });

  testWidgets('summary shows the firsts line after a fresh-profile run', (
    tester,
  ) async {
    final c = GameController(saveDirOverride: dir.path);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    // The ENTIRE controller drive must live inside runAsync: with a real
    // saveDirOverride every apply() initiates real file I/O, and I/O born in
    // the FakeAsync zone never completes (its completions queue behind fake
    // microtasks) — a later runAsync(flushSaves) cannot rescue it. Initiating
    // the saves on the real event loop is the only cure.
    await tester.runAsync(() async {
      c.startRun(character: 'kindler', seed: 503, boons: true);
      driveToTerminal(c);
      await c.flushSaves();
    });
    expect({'run_won', 'run_lost'}.contains(c.phase), isTrue);
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final line = find.byKey(const ValueKey('firsts-line'));
    await tester.ensureVisible(line);
    expect(line, findsOneWidget);
    final text = tester.widget<Text>(line).data!;
    expect(text, contains('First sighting: '));
    // v0.31.0 codex pull: a run that produced firsts also names the
    // collection — factual count, matching the live meta.
    final pull = find.byKey(const ValueKey('codex-pull-line'));
    await tester.ensureVisible(pull);
    expect(pull, findsOneWidget);
    expect(
      tester.widget<Text>(pull).data,
      'Their tales wait in the Codex — '
      '${c.meta.ownedCodex.length} of ${codexEntries.length} unsealed.',
    );
    await pumpFor(tester, 800);
  });

  testWidgets('summary hides firsts and codex pull when nothing was new', (
    tester,
  ) async {
    final c = GameController(saveDirOverride: dir.path);
    // Veteran record: every enemy already met AND felled, so no run can
    // produce a first of either kind — both lines must stay absent.
    for (final id in enemies.keys) {
      c.meta.enemyMet[id] = 5;
      c.meta.enemyFelled[id] = 3;
    }
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.runAsync(() async {
      c.startRun(character: 'kindler', seed: 503, boons: true);
      driveToTerminal(c);
      await c.flushSaves();
    });
    expect({'run_won', 'run_lost'}.contains(c.phase), isTrue);
    expect(c.runFirstMet, isEmpty);
    expect(c.runFirstFelled, isEmpty);
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('firsts-line')), findsNothing);
    expect(find.byKey(const ValueKey('codex-pull-line')), findsNothing);
    await pumpFor(tester, 800);
  });

  testWidgets('codex entry shows the free record line', (tester) async {
    final c = GameController(saveDirOverride: dir.path);
    c.meta.enemyMet['cinder_wisp'] = 3;
    c.meta.enemyFelled['cinder_wisp'] = 2;
    c.meta.enemyFellTo['cinder_wisp'] = 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await pumpFor(tester, 400);
    final record = find.byKey(const ValueKey('codex-record-cinder_wisp'));
    await tester.scrollUntilVisible(record, 120);
    expect(record, findsOneWidget);
    expect(
      tester.widget<Text>(record).data,
      'Met 3 \u00b7 Felled 2 \u00b7 Deaths 1',
    );
    // A never-met enemy states it plainly instead of showing zeros.
    final unmet = find.byKey(const ValueKey('codex-record-ash_rat'));
    await tester.scrollUntilVisible(unmet, 120);
    expect(tester.widget<Text>(unmet).data, 'Not yet met.');
    await pumpFor(tester, 400);
  });
}
