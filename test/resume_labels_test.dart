// Regression tests for the resumed-run identity bug (bug-hunt 2026-08-11):
// dailyDate / weeklyIndex / weeklyMutator lived only in controller memory, so
// killing the app mid-Daily/Weekly Delve and resuming turned the run into a
// plain one — _bankRun gates every daily/weekly record on those fields, so
// finishing the resumed run banked NO recap, NO share text and no played
// counter. The labels now ride alongside the sim snapshot ('run_labels') and
// boot() restores them.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/daily.dart';

/// Walk the current run to a terminal phase with the greedy autoplay bot
/// (proven to terminate across all seeds and mutators — the trivial
/// roll-without-assigning policy stalled on rare seeds under guard).
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
    dir = await Directory.systemTemp.createTemp('ed_resume_labels');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() async {
    MetaStore.dirOverride = null;
    await dir.delete(recursive: true);
  });

  test('the Weekly Delve is seed-pinned to the week (shared delve for all)',
      () async {
    // Bug-hunt 2026-08-11: weeklySeed existed and was unit-tested but was
    // never wired into startWeeklyRun, so every player got a random clock
    // seed — the "one shared delve, same seed for everyone" promise (UI blurb
    // and share text) was false. Two controllers starting the weekly must
    // land on the identical run seed, and it must be the week's canonical one.
    final c1 = GameController(saveDirOverride: dir.path);
    await c1.boot();
    c1.startWeeklyRun();
    final expected = weeklySeed(c1.weeklyIndex!);
    expect(c1.sim!.runSeed, expected,
        reason: 'weekly run must use weeklySeed(weekIndex), not the clock');

    final c2 = GameController(saveDirOverride: dir.path);
    await c2.boot();
    c2.startWeeklyRun();
    expect(c2.sim!.runSeed, expected,
        reason: 'two players starting the weekly must get the same delve');
  });

  test('a resumed Weekly Delve keeps its identity and banks its record',
      () async {
    final c1 = GameController(saveDirOverride: dir.path);
    await c1.boot();
    c1.startWeeklyRun();
    expect(c1.weeklyIndex, isNotNull);
    expect(c1.weeklyMutator, isNotNull);
    final index = c1.weeklyIndex!;
    final mutator = c1.weeklyMutator!;
    // Take one step so the autosave definitely ran, then "kill the app".
    if (c1.phase == 'boon') c1.apply({'type': 'choose_boon', 'index': 1});
    await c1.flushSaves();

    final c2 = GameController(saveDirOverride: dir.path);
    await c2.boot();
    expect(c2.phase, isNotNull, reason: 'saved run should resume');
    expect(c2.weeklyIndex, index,
        reason: 'resumed weekly lost its week index — its record will '
            'silently not bank when the run ends');
    expect(c2.weeklyMutator, mutator);

    driveToTerminal(c2);
    expect(c2.meta.lastWeeklyKey, weeklyKey(index),
        reason: 'finished resumed weekly must bank the weekly record');
    expect(c2.meta.weekliesPlayed, 1);
    expect(c2.weeklyResultShareText, isNotNull,
        reason: 'summary must still offer the weekly share text');
  });

  test('a resumed Daily Delve keeps its identity and banks its record',
      () async {
    final c1 = GameController(saveDirOverride: dir.path);
    await c1.boot();
    c1.startDailyRun();
    final label = c1.dailyDate;
    expect(label, isNotNull);
    if (c1.phase == 'boon') c1.apply({'type': 'choose_boon', 'index': 1});
    await c1.flushSaves();

    final c2 = GameController(saveDirOverride: dir.path);
    await c2.boot();
    expect(c2.dailyDate, label,
        reason: 'resumed daily lost its date label — its record will '
            'silently not bank when the run ends');

    driveToTerminal(c2);
    expect(c2.meta.lastDailyDate, label,
        reason: 'finished resumed daily must bank the daily record');
    expect(c2.dailyResultShareText, isNotNull);
  });

  test('normal runs write no labels and resume without any', () async {
    final c1 = GameController(saveDirOverride: dir.path);
    await c1.boot();
    c1.startRun(seed: 42);
    if (c1.phase == 'boon') c1.apply({'type': 'choose_boon', 'index': 1});
    await c1.flushSaves();
    final raw =
        await File('${dir.path}/emberdelve_run.json').readAsString();
    expect(raw.contains('run_labels'), isFalse,
        reason: 'normal-run save blobs must stay byte-identical to pre-fix');

    final c2 = GameController(saveDirOverride: dir.path);
    await c2.boot();
    expect(c2.dailyDate, isNull);
    expect(c2.weeklyIndex, isNull);
    expect(c2.weeklyMutator, isNull);
  });
}
