// test/hearth_song_test.dart — v0.75.0 "The Hearth Song": a heard
// Gramophone track pinned as the hearth's music. Design doc:
// docs/improvements/v0.75.0-lead-scout.md.
//
// Pins:
//   1. Persistence: hearthTrack round-trips json; absent key decodes ''.
//   2. Honesty: hearthSongKey falls back to 'title_menu' when the stored
//      key is unheard or unknown; setHearthSong refuses unheard keys.
//   3. Mapping: musicKeyForPhase title-family default returns the passed
//      hearthSong; run phases are untouched by it.
//   4. Cloud: fresher-wholesale like the other worn choices.
//   5. UI: heard rows carry the pin (hearth-song-<key>); pinning marks
//      gold; tapping the gold mark gives the song back; locked rows bare.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hearth_song');
    MetaStore.dirOverride = dir.path;
  });
  tearDown(() async {
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

  GameController quiet() => GameController(saveDirOverride: dir.path);

  test('hearthTrack persists and absent decodes to default', () {
    final m = MetaState()..hearthTrack = 'victory';
    final back = MetaState.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );
    expect(back.hearthTrack, 'victory');
    expect(MetaState.fromJson(const {}).hearthTrack, '');
    // Default is omitted from the save entirely.
    expect(MetaState().toJson().containsKey('hearthTrack'), isFalse);
  });

  test('honesty: unheard or unknown keys never sound', () {
    final c = quiet();
    // setHearthSong refuses a track the profile has not heard.
    c.setHearthSong('victory');
    expect(c.meta.hearthTrack, '');
    expect(c.hearthSongKey, 'title_menu');
    // Heard: accepted and resolved.
    c.meta.heardTracks.add('victory');
    c.setHearthSong('victory');
    expect(c.meta.hearthTrack, 'victory');
    expect(c.hearthSongKey, 'victory');
    // A stale value (cloud merge from a fresher profile that heard it)
    // resolves back to Hearthside without being erased.
    c.meta.heardTracks.remove('victory');
    expect(c.hearthSongKey, 'title_menu');
    expect(c.meta.hearthTrack, 'victory');
    // Unknown key never sounds even if somehow recorded as heard.
    c.meta.heardTracks.add('no_such_track');
    c.meta.hearthTrack = 'no_such_track';
    expect(c.hearthSongKey, 'title_menu');
    // '' gives the song back.
    c.meta.heardTracks.add('victory');
    c.setHearthSong('victory');
    c.setHearthSong('');
    expect(c.meta.hearthTrack, '');
  });

  test('mapping: hearth song replaces only the title-family default', () {
    expect(
      AudioService.musicKeyForPhase('idle', hearthSong: 'victory'),
      'victory',
    );
    expect(AudioService.musicKeyForPhase('idle'), 'title_menu');
    expect(AudioService.musicKeyForPhase('map', hearthSong: 'victory'), 'map');
    expect(
      AudioService.musicKeyForPhase(
        'player_turn',
        bossFight: true,
        hearthSong: 'victory',
      ),
      'boss_combat',
    );
  });

  test('cloud merge carries the fresher profile\'s song wholesale', () {
    final local = MetaState()
      ..lifetimeEmbers = 10
      ..hearthTrack = 'map';
    final cloud = MetaState()
      ..lifetimeEmbers = 99
      ..hearthTrack = 'victory';
    expect(mergeMetaStates(local, cloud).hearthTrack, 'victory');
    expect(mergeMetaStates(cloud, local).hearthTrack, 'victory');
  });

  testWidgets('the gramophone pin sets, marks gold, and gives back', (
    tester,
  ) async {
    final c = quiet();
    c.meta.heardTracks.addAll({'title_menu', 'victory'});
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final victoryPin = find.byKey(const ValueKey('hearth-song-victory'));
    await tester.scrollUntilVisible(victoryPin, 400, scrollable: scrollable);
    // scrollUntilVisible can leave the row at the very bottom edge where
    // taps miss — pull it well into the viewport first.
    await tester.drag(scrollable, const Offset(0, -250), warnIfMissed: false);
    await tester.pump();
    Color pinColor(String key) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(ValueKey('hearth-song-$key')),
            matching: find.byType(Icon),
          ),
        )
        .color!;
    // Default: Hearthside carries the gold mark.
    expect(pinColor('title_menu'), EmberColors.gold);
    expect(pinColor('victory'), isNot(EmberColors.gold));
    // Unheard rows have no pin at all.
    expect(find.byKey(const ValueKey('hearth-song-defeat')), findsNothing);
    // Pin The Climb Home.
    await tester.tap(victoryPin);
    await tester.pump();
    expect(c.meta.hearthTrack, 'victory');
    expect(pinColor('victory'), EmberColors.gold);
    expect(pinColor('title_menu'), isNot(EmberColors.gold));
    // Tapping the gold mark gives the song back.
    await tester.tap(victoryPin);
    await tester.pump();
    expect(c.meta.hearthTrack, '');
    expect(pinColor('title_menu'), EmberColors.gold);
  });
}
