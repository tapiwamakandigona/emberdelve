// test/tempered_hand_test.dart — v0.125.0 The Tempered Hand.
//
// The Face Forge's lifetime arc: tempers bank at run end from the run's
// own tempers_used — wins AND losses (the forge work was real either
// way) — survive the save round-trip, merge MAX, and drive two honors.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a finished run banks its tempers, win or lose', () {
    // Kindler easy seed 13 loses AND visits a rest on the pure bot walk
    // (hunted 2026-08-30). The mid-run temper can sway the rest of the
    // walk (a mend rune heals), so the pin is on BANKING at the terminal
    // — the banking site sits outside the win gate by construction, and
    // statelessly counts run['tempers_used'] whatever the outcome.
    final c = GameController();
    c.meta.tutorialSeen = true;
    c.startRun(character: 'kindler', seed: 13, difficulty: 'easy');
    var guard = 0;
    var tempered = false;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
      if (c.phase == 'rest' && (c.state!['run'] as Map)['tempers_used'] == 0) {
        c.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'mend'});
        tempered = true;
        continue;
      }
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(tempered, isTrue, reason: 'seed 13 must reach a rest');
    expect(
      c.phase,
      anyOf('run_won', 'run_lost'),
      reason: 'the run must actually finish',
    );
    expect(c.meta.tempersSet, 1, reason: 'the finish banked the temper');
  });

  test('tempers survive the round-trip and merge MAX', () {
    final m = MetaState();
    expect(m.toJson().containsKey('tempersSet'), isFalse);
    m.tempersSet = 7;
    expect(MetaState.fromJson(m.toJson()).tempersSet, 7);
    final merged = mergeMetaStates(
      MetaState()..tempersSet = 7,
      MetaState()..tempersSet = 3,
    );
    expect(merged.tempersSet, 7);
  });

  test('the honors read the real counter', () {
    final m = MetaState();
    expect(statValue(m, 'tempers_set', null), 0);
    m.tempersSet = 1;
    expect(earnedAchievements(m), contains('first_temper'));
    expect(earnedAchievements(m), isNot(contains('well_tempered')));
    m.tempersSet = 25;
    expect(earnedAchievements(m), contains('well_tempered'));
  });

  test('temper honor copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    for (final id in ['first_temper', 'well_tempered']) {
      final t = '${achievements[id]!.name} ${achievements[id]!.text}'
          .toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
