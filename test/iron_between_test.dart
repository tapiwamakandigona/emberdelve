// test/iron_between_test.dart — v0.48.0 "The Iron Between": elite fights get
// their own combat theme between the regular piece and the crowned-boss
// piece, and the new track joins the Gramophone as the eighth record.
//
// Pins:
//   1. Static rule: musicKeyForPhase plays 'combat_elite' for an elite
//      fight, 'boss_combat' for a crowned foe (boss outranks elite), and
//      'combat' otherwise; eliteFight never touches non-combat phases.
//   2. Asset honesty: musicPaths['combat_elite'] points at a real bundled
//      file.
//   3. A played run records the iron: seed 2 easy win (kindler) crosses an
//      elite on the road down, so heardTracks gains 'combat_elite' AND
//      'boss_combat' as separate records; seed 1 easy win meets no elite
//      and must NOT record it — gameplay-owned, audio null.
//
// Seed 1 easy win is the same pinned run gramophone_test uses; seed 2 was
// pinned for this test (kindler, boons, easy — bot route crosses an elite).
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
    dir = await Directory.systemTemp.createTemp('iron_between_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('elite fights get their own theme; a crowned foe outranks it', () {
    expect(AudioService.musicKeyForPhase('player_turn'), 'combat');
    expect(AudioService.musicKeyForPhase('player_turn', eliteFight: true),
        'combat_elite');
    expect(AudioService.musicKeyForPhase('player_turn', bossFight: true),
        'boss_combat');
    expect(
        AudioService.musicKeyForPhase('player_turn',
            bossFight: true, eliteFight: true),
        'boss_combat',
        reason: 'the crown outranks the iron');
    // eliteFight never leaks into non-combat phases.
    for (final phase in ['boon', 'map', 'reward', 'shop', 'event', 'rest']) {
      expect(AudioService.musicKeyForPhase(phase, eliteFight: true), 'map',
          reason: '$phase ignores eliteFight');
    }
    expect(AudioService.musicKeyForPhase('run_won', eliteFight: true),
        'victory');
    expect(AudioService.musicKeyForPhase('run_lost', eliteFight: true),
        'defeat');
    expect(AudioService.musicKeyForPhase(null, eliteFight: true),
        'title_menu');
  });

  test('combat_elite points at a real bundled asset', () async {
    final path = AudioService.musicPaths['combat_elite'];
    expect(path, 'audio/music/combat_elite.ogg');
    final data = await rootBundle.load('assets/$path');
    expect(data.lengthInBytes, greaterThan(100 * 1024),
        reason: 'the elite theme is a real track, not a placeholder');
  });

  test('a run that crosses an elite records the iron as its own record',
      () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 2, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 2 must win on easy');
    expect(c.meta.heardTracks, contains('combat_elite'),
        reason: 'the seed-2 road crosses an elite');
    expect(c.meta.heardTracks, contains('boss_combat'),
        reason: 'the crowned record is earned separately, not via elites');
    await c.flushSaves();
  });

  test('a run that meets no elite does not record the iron', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.meta.heardTracks, isNot(contains('combat_elite')),
        reason: 'no elite on the seed-1 road — the record stays honest');
    expect(c.meta.heardTracks, contains('boss_combat'),
        reason: 'the boss still records the crowned theme');
    await c.flushSaves();
  });
}
