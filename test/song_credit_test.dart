// test/song_credit_test.dart — v0.84.0 The Song Credit.
//
// The first time a track ever plays, the flash toast names it — once per
// track per profile, hooked on heardTracks growth. Pure controller checks:
// the flash field is the toast contract (game_root shows and clears it).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';

void main() {
  test('the first delve credits Into the Delve at the map', () {
    final c = GameController();
    expect(c.meta.heardTracks.contains('map'), isFalse);
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    expect(c.meta.heardTracks.contains('map'), isTrue);
    expect(c.flash, '"Into the Delve" — first hearing');
  });

  test('a heard song is never credited again', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    c.flash = null;
    c.endToTitle();
    c.startRun(character: 'kindler', seed: 2, difficulty: 'easy');
    expect(c.flash, isNull);
  });
}
