// test/charted_depth_test.dart — v0.65.0 "The Charted Depth": each delver's
// deepest floor, banked per character (charBestFloor) and appended to the
// picker tally line ("5 wins · 12 delves · floor 6"). Design doc:
// docs/improvements/v0.65.0-lead-scout.md.
//
// Pins:
//   1. Banking: a finished run moves this character's charted depth and
//      leaves every other delver's untouched; a shallower re-run never
//      lowers it.
//   2. Save round-trip: charBestFloor survives toJson/fromJson; an empty
//      map emits no key (pre-v0.65.0 saves stay byte-identical).
//   3. Seeding: a pre-v0.65.0 save (no charBestFloor key) seeds per-delver
//      depths from the run history — only what the ledger can prove.
//   4. Cloud merge: per-key MAX, same convention as charRuns/charWins.
//   5. Widget: the picker tally appends "· floor N" when a depth exists and
//      shows the plain v0.60.0 tally when none does — never a guessed floor.
//
// Seeds: 1 wins on easy (kindler, boons — pinned table, post-v0.47.0).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 4000, isTrue, reason: 'bot run failed to terminate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('charted_depth_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a finished run charts this delver and only this delver', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.charBestFloor['warden'] = 3; // someone else's standing record
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(
      c.meta.charBestFloor['kindler'],
      c.meta.bestFloor,
      reason: 'first kindler run: charted depth equals the global mark',
    );
    expect(
      c.meta.charBestFloor['warden'],
      3,
      reason: 'another delver\'s record never moves',
    );
    await c.flushSaves();
  });

  test('a shallower re-run never lowers the charted depth', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.charBestFloor['kindler'] = 99; // impossibly deep standing record
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.meta.charBestFloor['kindler'], 99);
    await c.flushSaves();
  });

  test('save round-trip; empty map emits no key', () {
    final m = MetaState(charBestFloor: {'kindler': 4, 'peddler': 2});
    final back = MetaState.fromJson(m.toJson());
    expect(back.charBestFloor, {'kindler': 4, 'peddler': 2});
    expect(
      MetaState().toJson().containsKey('charBestFloor'),
      isFalse,
      reason: 'pre-charted saves stay byte-identical',
    );
  });

  test('a pre-v0.65.0 save seeds charted depths from the run history', () {
    final old = MetaState(
      runHistory: [
        {'character': 'kindler', 'floor': 5},
        {'character': 'kindler', 'floor': 2},
        {'character': 'warden', 'floor': 7},
        {'floor': 9}, // malformed record: no character — proves nothing
      ],
    ).toJson()..remove('charBestFloor');
    final back = MetaState.fromJson(old);
    expect(back.charBestFloor, {'kindler': 5, 'warden': 7});
    // But a save that HAS the key never re-seeds (an explicit empty map on
    // a wiped profile stays empty even with history present).
    final kept = MetaState.fromJson({
      'charBestFloor': {'kindler': 1},
      'runHistory': [
        {'character': 'kindler', 'floor': 6},
      ],
    });
    expect(kept.charBestFloor, {'kindler': 1});
  });

  test('cloud merge takes the per-key MAX', () {
    final local = MetaState(charBestFloor: {'kindler': 4, 'warden': 1});
    final cloud = MetaState(charBestFloor: {'kindler': 2, 'gambler': 6});
    final m = mergeMetaStates(local, cloud);
    expect(m.charBestFloor, {'kindler': 4, 'warden': 1, 'gambler': 6});
  });

  testWidgets('the picker tally appends the charted floor', (tester) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 12;
    c.meta.charWins['kindler'] = 5;
    c.meta.charBestFloor['kindler'] = 6;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('char-tally-kindler')), findsOneWidget);
    expect(find.text('5 wins · 12 delves · floor 6'), findsOneWidget);
  });

  testWidgets('no charted depth: the plain v0.60.0 tally, no guessed floor', (
    tester,
  ) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 12;
    c.meta.charWins['kindler'] = 5;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.text('5 wins · 12 delves'), findsOneWidget);
    expect(find.textContaining('floor'), findsNothing);
  });
}
