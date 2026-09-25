// test/song_credit_test.dart — v0.84.0 The Song Credit.
//
// The first time a track ever plays, the flash toast names it — once per
// track per profile, hooked on heardTracks growth. Pure controller checks:
// the flash field is the toast contract (game_root shows and clears it).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';

void _playOut(GameController c) {
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

void main() {
  test('the first delve banks Into the Delve quietly (v0.180.0)', () {
    // The Quiet First Delve: a fresh profile's first run shows no song
    // credit — the toast used to land on the first decision screen. The
    // fact still banks; the summary's new-song line names the songs.
    final c = GameController();
    expect(c.meta.runsPlayed, 0);
    expect(c.meta.heardTracks.contains('map'), isFalse);
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    expect(c.meta.heardTracks.contains('map'), isTrue);
    expect(c.runNewTracks, contains('map'));
    expect(c.flash, isNull);
  });

  test('from the second delve on, a first hearing is credited', () {
    final c = GameController();
    c.meta.runsPlayed = 1;
    expect(c.meta.heardTracks.contains('map'), isFalse);
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    expect(c.flash, '"Into the Delve" — first hearing');
  });

  test('a heard song is never credited again', () {
    final c = GameController();
    c.meta.runsPlayed = 1;
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    c.flash = null;
    c.endToTitle();
    c.startRun(character: 'kindler', seed: 2, difficulty: 'easy');
    expect(c.flash, isNull);
  });

  // exp.5 (critic C2-05): the run-end track is first heard AFTER banking has
  // already moved runsPlayed to 1, so the first defeat/victory screen of a
  // brand-new profile used to get a song-credit toast over its buttons.
  test('a fresh profile losing its first delve gets no credit toast', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 22, difficulty: 'easy');
    _playOut(c);
    expect(c.phase, 'run_lost');
    expect(c.meta.runsPlayed, 1);
    expect(c.flash ?? '', isNot(contains('first hearing')));
  });

  test('a fresh profile winning its first delve gets no credit toast', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    _playOut(c);
    expect(c.phase, 'run_won');
    expect(c.flash ?? '', isNot(contains('first hearing')));
  });

  test('credits resume on the second delve after a quiet first one', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 22, difficulty: 'easy');
    _playOut(c);
    c.endToTitle();
    c.meta.heardTracks.remove('map');
    c.startRun(character: 'kindler', seed: 2, difficulty: 'easy');
    expect(c.flash, '"Into the Delve" — first hearing');
  });
}
