// test/deeper_song_test.dart — v0.45.0 "The Deeper Song": the map-family
// music darkens past the delve's midpoint, driven by the SAME depth signal
// the Deep Hum ambience uses (controller.mapDepth), and the new track joins
// the Gramophone like any other record.
//
// Pins:
//   1. Static rule: musicKeyForPhase returns 'map' above the midpoint and
//      'map_deep' at/past it, for every map-family phase; combat, boss,
//      victory, defeat and title are untouched by depth.
//   2. Asset honesty: musicPaths['map_deep'] points at a real bundled file.
//   3. A played run records the deep song: seed 1 easy win (kindler) walks
//      past the midpoint on its way to the boss, so heardTracks gains
//      'map_deep' alongside map/combat/victory — gameplay-owned, audio null.
//
// Seed 1 easy win is the same pinned run gramophone_test uses.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';

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
    dir = await Directory.systemTemp.createTemp('deeper_song_test');
  });
  tearDown(() async {
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('map-family phases darken at the midpoint; nothing else does', () {
    const mapFamily = ['boon', 'map', 'reward', 'shop', 'event', 'rest'];
    for (final phase in mapFamily) {
      expect(
        AudioService.musicKeyForPhase(phase),
        'map',
        reason: '$phase with no depth stays shallow',
      );
      expect(
        AudioService.musicKeyForPhase(phase, mapDepth: 0.49),
        'map',
        reason: '$phase just above the midpoint stays shallow',
      );
      expect(
        AudioService.musicKeyForPhase(phase, mapDepth: 0.5),
        'map_deep',
        reason: '$phase at the midpoint darkens',
      );
      expect(
        AudioService.musicKeyForPhase(phase, mapDepth: 1.0),
        'map_deep',
        reason: '$phase on the boss layer darkens',
      );
    }
    // Depth never touches the non-map keys.
    expect(
      AudioService.musicKeyForPhase('player_turn', mapDepth: 1.0),
      'combat',
    );
    expect(
      AudioService.musicKeyForPhase(
        'player_turn',
        bossFight: true,
        mapDepth: 1.0,
      ),
      'boss_combat',
    );
    expect(AudioService.musicKeyForPhase('run_won', mapDepth: 1.0), 'victory');
    expect(AudioService.musicKeyForPhase('run_lost', mapDepth: 1.0), 'defeat');
    expect(AudioService.musicKeyForPhase(null, mapDepth: 1.0), 'title_menu');
  });

  test('map_deep points at a real bundled asset', () async {
    final path = AudioService.musicPaths['map_deep'];
    expect(path, 'audio/music/map_deep.ogg');
    final data = await rootBundle.load('assets/$path');
    expect(
      data.lengthInBytes,
      greaterThan(100 * 1024),
      reason: 'the deep song is a real track, not a placeholder',
    );
  });

  test('a won run walks past the midpoint and records the deep song', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(
      c.meta.heardTracks,
      contains('map_deep'),
      reason: 'the road to the boss crosses the midpoint',
    );
    expect(
      c.meta.heardTracks,
      containsAll({'map', 'combat', 'victory'}),
      reason: 'the shallow records still land first',
    );
    await c.flushSaves();
  });
}
