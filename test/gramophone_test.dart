// test/gramophone_test.dart — v0.33.0 "The Gramophone": the soundtrack as a
// collection in the Ledger. Tracks unlock by playing; MetaState.heardTracks
// records them (gameplay-owned, computed from the same static rule the audio
// layer uses — testable with audio == null).
//
// Pins:
//   1. Catalog integrity: gramophoneTracks keys == AudioService.musicPaths
//      keys, exactly, and every hint passes the §Ethics banned-word sweep.
//   2. Meta round-trip: heardTracks persists through toJson/fromJson; a
//      legacy JSON without the field decodes to empty (boot seeds the hearth).
//   3. boot() seeds 'title_menu' on every profile, legacy included.
//   4. A played run records the run tracks: seed 1 easy win → map, combat,
//      victory all heard; seed 13 easy loss → defeat heard, victory not.
//   5. Cloud merge unions heardTracks.
//   6. Ledger widget: an unheard track hides its name behind '— — —' and
//      shows its earn-hint; a heard track shows its name.
//
// Seeds: 1 wins on easy (kindler, boons); 13 loses on easy — the same pinned
// pair rung_open_test uses.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
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

const bannedWords = [
  'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
  'bet you', 'only today', "can't", 'loser', //
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gramophone_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('catalog matches AudioService.musicPaths and copy is charter-clean',
      () {
    final catalogKeys = gramophoneTracks.map((t) => t.key).toSet();
    expect(catalogKeys, AudioService.musicPaths.keys.toSet(),
        reason: 'every music track is in the Gramophone, nothing invented');
    expect(gramophoneTracks.length, AudioService.musicPaths.length,
        reason: 'no duplicate keys');
    for (final t in gramophoneTracks) {
      final copy = '${t.name} ${t.hint}'.toLowerCase();
      for (final w in bannedWords) {
        expect(copy.contains(w), isFalse,
            reason: 'banned word "$w" in track copy for ${t.key}');
      }
    }
  });

  test('heardTracks round-trips; legacy JSON decodes to empty', () {
    final m = MetaState(heardTracks: {'title_menu', 'map', 'victory'});
    final back = MetaState.fromJson(
        Map<String, dynamic>.from(m.toJson()));
    expect(back.heardTracks, {'title_menu', 'map', 'victory'});
    // Legacy save: no heardTracks key at all.
    final legacy = MetaState.fromJson({'embers': 5, 'runsPlayed': 3});
    expect(legacy.heardTracks, isEmpty,
        reason: 'boot(), not fromJson, seeds the hearth');
    // Empty set stays omitted so pre-v0.33 saves stay byte-identical.
    expect(MetaState().toJson().containsKey('heardTracks'), isFalse);
  });

  test('boot seeds the hearth theme on every profile', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    expect(c.meta.heardTracks, contains('title_menu'));
    await c.flushSaves();
  });

  test('a won run records map, combat and victory', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.meta.heardTracks, containsAll({'map', 'combat', 'victory'}));
    expect(c.meta.heardTracks, isNot(contains('defeat')));
    await c.flushSaves();
  });

  test('a lost run records defeat, not victory', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 13, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost', reason: 'seed 13 must lose on easy');
    expect(c.meta.heardTracks, contains('defeat'));
    expect(c.meta.heardTracks, isNot(contains('victory')));
    await c.flushSaves();
  });

  test('cloud merge unions heardTracks', () {
    final local = MetaState(heardTracks: {'title_menu', 'map'});
    final cloud = MetaState(heardTracks: {'title_menu', 'victory'});
    final merged = mergeMetaStates(local, cloud);
    expect(merged.heardTracks, {'title_menu', 'map', 'victory'});
  });

  testWidgets('Ledger hides unheard tracks and names heard ones',
      (tester) async {
    final c = GameController();
    c.meta.heardTracks.addAll({'title_menu', 'map'});
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: LedgerScreen(c),
    ));
    await tester.pump();
    final list = find.byType(ListView);
    // Heard: named.
    await tester.scrollUntilVisible(find.text('Hearthside'), 400,
        scrollable: find.descendant(
            of: list, matching: find.byType(Scrollable)));
    expect(find.text('Hearthside'), findsOneWidget);
    expect(find.text('Into the Delve'), findsOneWidget);
    // Unheard: masked, hint visible.
    expect(find.text('Steel and Ember'), findsNothing);
    expect(find.text('The Climb Home'), findsNothing);
    expect(find.text('Win a delve.'), findsOneWidget);
    // v0.45.0: 7 tracks, 2 heard => 5 masked.
    expect(find.text('— — —'), findsNWidgets(5));
  });
}
