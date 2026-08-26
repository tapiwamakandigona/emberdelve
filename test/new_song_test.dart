// test/new_song_test.dart — v0.76.0 "The New Song": tracks first heard
// during a run are announced ONCE at the summary (key 'new-song-line').
// Design doc: docs/improvements/v0.76.0-lead-scout.md.
//
// Pins:
//   1. A fresh profile's first win records the run's new tracks (victory
//      included, title_menu never) and the set is run-scoped.
//   2. A second identical run earns nothing — the set stays empty and the
//      summary stays silent (announce-once, the pendingEpithets rule).
//   3. The line collapses: one name quoted, two names joined, three-or-more
//      become '"first" and N more' — a first delve never shouts four lines.
//   4. Resume: the side channel ('run_new_tracks') round-trips a mid-run
//      save, so a resumed run still gets its line.
//   5. Widget: the summary shows 'new-song-line' with the exact collapsed
//      text on a first win.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
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
    dir = await Directory.systemTemp.createTemp('new_song');
    MetaStore.dirOverride = dir.path;
  });
  tearDown(() async {
    MetaStore.dirOverride = null;
    await dir.delete(recursive: true);
  });

  test('a first win records the run\'s new tracks, title_menu never', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    expect(c.meta.heardTracks, {'title_menu'}, reason: 'fresh profile');
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.runNewTracks, isNotEmpty);
    expect(c.runNewTracks, contains('victory'));
    expect(c.runNewTracks, isNot(contains('title_menu')));
    // Every announced song really is in the lifetime record (honesty).
    expect(c.meta.heardTracks.containsAll(c.runNewTracks), isTrue);
    await c.flushSaves();
  });

  test('a second identical run earns nothing and startRun clears', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.runNewTracks, isNotEmpty);
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    expect(c.runNewTracks, isEmpty, reason: 'run-scoped: cleared on start');
    driveToTerminal(c);
    expect(
      c.runNewTracks,
      isEmpty,
      reason: 'every track this run plays was already heard',
    );
    await c.flushSaves();
  });

  test('the line collapses to one sentence at every count', () {
    expect(
      newSongLine(const ['Into the Delve']),
      '"Into the Delve" joins the Gramophone.',
    );
    expect(
      newSongLine(const ['Into the Delve', 'Steel and Ember']),
      '"Into the Delve" and "Steel and Ember" join the Gramophone.',
    );
    expect(
      newSongLine(const [
        'Into the Delve',
        'Steel and Ember',
        'Deeper Still',
        'The Climb Home',
      ]),
      '"Into the Delve" and 3 more join the Gramophone.',
    );
  });

  test('resume: the side channel round-trips a mid-run save', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    // Step until at least one track is newly heard, staying non-terminal.
    var guard = 0;
    while (c.runNewTracks.isEmpty && guard++ < 200) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.runNewTracks, isNotEmpty, reason: 'a delve hears music early');
    expect(c.phase, isNot(anyOf('run_won', 'run_lost')));
    final earned = Set<String>.from(c.runNewTracks);
    await c.flushSaves();

    final resumed = GameController(saveDirOverride: dir.path);
    await resumed.boot();
    expect(resumed.sim, isNotNull, reason: 'mid-run save resumes');
    expect(resumed.runNewTracks, earned);
  });

  testWidgets('the summary shows the collapsed line on a first win', (
    tester,
  ) async {
    // No boot() and no saveDirOverride here: real file IO never completes
    // inside the widget-test zone (fake async), and pointing autosaves at
    // the temp dir races its teardown delete. A fresh MetaState has heard
    // nothing, which is the first-win premise anyway.
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final line = find.byKey(const ValueKey('new-song-line'));
    await tester.scrollUntilVisible(line, -200);
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).data, newSongLine(newSongNames(c)));
  });
}
