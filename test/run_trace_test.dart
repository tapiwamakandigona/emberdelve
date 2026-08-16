// test/run_trace_test.dart — v0.8.0 "Tell the Tale" share trace:
//   1. RunTrace marks floors clean/hurt from sim events only; the terminal
//      event closes the last floor.
//   2. traceGrid renders 🟩/🟨 rows of five, 🟥 on the death floor, 🔥 on a
//      claimed boss floor; empty trace renders ''.
//   3. toJson/fromJson round-trips, including a half-open floor (kill+resume
//      mid-floor loses nothing).
//   4. Share texts stay honest: daily/weekly gain the grid without losing a
//      single existing fact; seedChallengeText has no streak/expiry/taunt
//      language (§Ethics) and quotes the exact seed.
//   5. End-to-end: a real controller run produces a trace whose length
//      matches the floors actually walked, and the summary getters carry it.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';

List<Map<String, Object?>> ev(List<Map<String, Object?>> list) => list;

/// Bot-drive to terminal, counting the floors actually entered.
int driveToTerminal(GameController c) {
  var floors = 0;
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 3000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    final events = c.apply(cmd);
    floors += events.where((e) => e['type'] == 'node_entered').length;
  }
  expect(guard < 3000, isTrue, reason: 'bot run failed to terminate');
  return floors;
}

void main() {
  group('RunTrace.observe', () {
    test('clean floor then hurt floor then death', () {
      final t = RunTrace();
      t.observe(
        ev([
          {'type': 'node_entered', 'node': 1, 'kind': 'fight', 'layer': 1},
          {'type': 'enemy_attacked', 'amount': 3, 'blocked': 3, 'damage': 0},
        ]),
      );
      t.observe(
        ev([
          {'type': 'node_entered', 'node': 2, 'kind': 'fight', 'layer': 2},
          {'type': 'enemy_attacked', 'amount': 5, 'blocked': 0, 'damage': 5},
        ]),
      );
      t.observe(
        ev([
          {'type': 'node_entered', 'node': 3, 'kind': 'fight', 'layer': 3},
          {'type': 'enemy_attacked', 'amount': 9, 'blocked': 0, 'damage': 9},
          {'type': 'run_lost'},
        ]),
      );
      expect(t.marks, ['clean', 'hurt', 'hurt']);
      expect(t.outcome, 'lost');
    });

    test('fully-blocked hits stay clean; event hp_lost marks hurt', () {
      final t = RunTrace();
      t.observe(
        ev([
          {'type': 'node_entered', 'node': 1, 'kind': 'event', 'layer': 1},
          {'type': 'hp_lost', 'amount': 2, 'hp': 20},
          {'type': 'run_won'},
        ]),
      );
      expect(t.marks, ['hurt']);
      expect(t.outcome, 'won');
    });

    test('irrelevant events never open or mark a floor', () {
      final t = RunTrace();
      t.observe(
        ev([
          {'type': 'run_started'},
          {'type': 'dice_rolled'},
          {'type': 'embers_gained', 'amount': 4},
        ]),
      );
      expect(t.isEmpty, isTrue);
      expect(traceGrid(t), '');
    });
  });

  group('traceGrid', () {
    RunTrace make(List<String> marks, String? outcome) {
      final t = RunTrace();
      for (final m in marks) {
        t.observe(
          ev([
            {'type': 'node_entered', 'node': 0, 'kind': 'fight', 'layer': 0},
            if (m == markHurt)
              {'type': 'enemy_attacked', 'amount': 1, 'damage': 1},
          ]),
        );
      }
      if (outcome == 'won') {
        t.observe(ev([{'type': 'run_won'}]));
      }
      if (outcome == 'lost') {
        t.observe(ev([{'type': 'run_lost'}]));
      }
      return t;
    }

    test('rows of five, death floor red', () {
      final t = make([
        markClean, markHurt, markClean, markClean, markHurt,
        markClean, markHurt,
      ], 'lost');
      expect(traceGrid(t), '🟩🟨🟩🟩🟨\n🟩🟥');
    });

    test('claimed boss floor burns', () {
      final t = make([markClean, markClean, markHurt], 'won');
      expect(traceGrid(t), '🟩🟩🔥');
    });

    test('exactly five floors stays one row', () {
      final t = make(List.filled(5, markClean), 'won');
      expect(traceGrid(t), '🟩🟩🟩🟩🔥');
      expect(traceGrid(t).contains('\n'), isFalse);
    });

    test('semantic label counts honestly', () {
      final t = make([markClean, markHurt, markHurt], 'won');
      final label = traceSemanticLabel(t);
      expect(label, contains('3 floors'));
      expect(label, contains('1 unharmed'));
      expect(label, contains('2 with blood spilt'));
      expect(label, contains('Ember claimed'));
    });
  });

  group('persistence round-trip', () {
    test('closed floors, outcome, and an OPEN floor all survive', () {
      final t = RunTrace();
      t.observe(
        ev([
          {'type': 'node_entered', 'node': 1, 'kind': 'fight', 'layer': 1},
          {'type': 'enemy_attacked', 'amount': 2, 'damage': 2},
          {'type': 'node_entered', 'node': 2, 'kind': 'fight', 'layer': 2},
          {'type': 'enemy_attacked', 'amount': 4, 'damage': 4},
        ]),
      );
      // Floor 2 is still open (mid-fight kill+resume).
      final back = RunTrace.fromJson(t.toJson());
      expect(back.marks, ['hurt']);
      // Resumed run finishes the open floor: the earlier damage still counts.
      back.observe(ev([{'type': 'run_lost'}]));
      expect(back.marks, ['hurt', 'hurt']);
      expect(back.outcome, 'lost');
    });

    test('garbage json yields a clean empty trace', () {
      expect(RunTrace.fromJson(null).isEmpty, isTrue);
      expect(RunTrace.fromJson('nope').isEmpty, isTrue);
      expect(RunTrace.fromJson({'marks': 'nope'}).isEmpty, isTrue);
      expect(
        RunTrace.fromJson({'marks': ['clean', 'bogus', 'hurt']}).marks,
        ['clean', 'hurt'],
      );
    });
  });

  group('share text honesty', () {
    test('daily text keeps every existing fact and gains the grid', () {
      final text = dailyShareText(
        date: '2026-08-16',
        won: true,
        floor: 8,
        floors: 8,
        grid: '🟩🟩🔥',
      );
      expect(text, contains('Emberdelve Daily 2026-08-16'));
      expect(text, contains('🟩🟩🔥'));
      expect(text, contains('Claimed the Ember'));
      expect(text, contains('One shared delve — same seed for everyone.'));
      // Grid sits between header and result line.
      final lines = text.split('\n');
      expect(lines.indexOf('🟩🟩🔥'), 1);
    });

    test('daily text without a grid is byte-identical to the old format', () {
      expect(
        dailyShareText(date: '2026-08-16', won: false, floor: 3, floors: 8),
        'Emberdelve Daily 2026-08-16\n'
        '🕯️ Fell on floor 3 of 8\n'
        'One shared delve — same seed for everyone.',
      );
    });

    test('weekly text gains the grid the same way', () {
      final text = weeklyShareText(
        index: 12,
        mutatorId: 'nonsense_id',
        won: false,
        floor: 4,
        floors: 8,
        grid: '🟨🟨🟨🟥',
      );
      expect(text.split('\n')[1], '🟨🟨🟨🟥');
      expect(text, contains('same seed and modifier for everyone.'));
    });

    test('seed challenge quotes seed, difficulty, and replay path', () {
      final text = seedChallengeText(
        seed: 123456789,
        difficulty: 'hard',
        ascension: 3,
        won: true,
        floor: 8,
        floors: 8,
        grid: '🟩🟨🔥',
      );
      expect(text, contains('seed 123456789'));
      expect(text, contains('HARD A3'));
      expect(text, contains('🟩🟨🔥'));
      expect(text, contains('Delve a seed'));
    });

    test('share copy carries no pressure language (§Ethics)', () {
      final all = [
        seedChallengeText(
          seed: 42,
          difficulty: 'normal',
          ascension: 0,
          won: false,
          floor: 2,
          floors: 8,
        ),
        dailyShareText(
          date: '2026-08-16',
          won: false,
          floor: 2,
          floors: 8,
          grid: '🟨🟥',
        ),
      ].join(' ').toLowerCase();
      for (final banned in [
        'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
        'bet you', 'only today', "can't", 'loser',
      ]) {
        expect(all.contains(banned), isFalse, reason: 'found "$banned"');
      }
    });
  });

  group('end to end through the controller', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ed_run_trace');
      MetaStore.dirOverride = dir.path;
    });

    tearDown(() async {
      // Same drain-then-retry charter as resume_labels_test: unawaited saves
      // racing the recursive delete throw "Directory not empty" on CI.
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

    test('one mark per floor walked; getters carry grid and seed', () async {
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.startRun(character: 'kindler', seed: 20260816);
      final floors = driveToTerminal(c);
      expect(floors, greaterThan(0));
      expect(c.runTrace.marks.length, floors,
          reason: 'every node_entered must close into exactly one mark');
      expect(c.runTrace.outcome, c.phase == 'run_won' ? 'won' : 'lost');

      final grid = traceGrid(c.runTrace);
      expect(grid, isNotEmpty);
      final share = c.seedChallengeShareText;
      expect(share, isNotNull, reason: 'normal finished run offers the seed');
      expect(share, contains('seed 20260816'));
      expect(share, contains(grid.split('\n').first));
      expect(c.dailyResultShareText, isNull);
      await c.flushSaves();
    });

    test('a second run never inherits the first trace', () async {
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.startRun(character: 'kindler', seed: 111);
      driveToTerminal(c);
      final first = c.runTrace.marks.length;
      expect(first, greaterThan(0));
      c.startRun(character: 'kindler', seed: 222);
      expect(c.runTrace.isEmpty, isTrue, reason: 'stale trace leaked');
      expect(c.seedChallengeShareText, isNull, reason: 'mid-run: no share');
      driveToTerminal(c);
      await c.flushSaves();
    });

    test('kill + resume keeps the floors already walked', () async {
      // Find a seed the bot survives past two floors (self-selecting so a
      // future sim re-anchor can't strand this test on a dead seed; the walk
      // itself is fully deterministic once a seed qualifies).
      GameController c1 = GameController(saveDirOverride: dir.path);
      await c1.boot();
      var found = false;
      for (var seed = 333; seed < 383 && !found; seed++) {
        c1.startRun(character: 'kindler', seed: seed);
        var guard = 0;
        while (c1.runTrace.marks.length < 2 && guard++ < 500) {
          final cmd = botCmd(c1.sim!);
          if (cmd == null) break;
          c1.apply(cmd);
          if (c1.phase == 'run_won' || c1.phase == 'run_lost') break;
        }
        found = c1.runTrace.marks.length >= 2 &&
            c1.phase != 'run_won' &&
            c1.phase != 'run_lost';
      }
      expect(found, isTrue,
          reason: 'no seed in [333,383) survives two floors under the bot');
      final walked = List<String>.from(c1.runTrace.marks);
      await c1.flushSaves();

      final c2 = GameController(saveDirOverride: dir.path);
      await c2.boot();
      expect(c2.phase, isNotNull, reason: 'saved run should resume');
      expect(c2.runTrace.marks, walked,
          reason: 'resumed run lost its floor trace — share text would lie');
      driveToTerminal(c2);
      expect(c2.runTrace.marks.length, greaterThanOrEqualTo(walked.length));
      expect(c2.runTrace.outcome, isNotNull);
      await c2.flushSaves();
    });
  });
}
