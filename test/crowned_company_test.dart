// test/crowned_company_test.dart — v0.123.0 The Crowned Company.
//
// Hard-mode mastery charted per delver: charHardWins banks only on hard
// wins, survives the save round-trip, merges per-key MAX, feeds the
// junk-proof delvers_crowned stat, and shows in both tallies only once a
// crown exists (the charted-depth no-guessing rule).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bot-finish a run at [difficulty]; returns the controller after banking.
GameController finishedRun(String difficulty, {required int seed}) {
  final c = GameController();
  c.meta.tutorialSeen = true;
  // Hard rides the Forge (clampRunParams silently downgrades otherwise —
  // the retraced_page idiom: a hard run implies a Forge profile).
  c.meta.forgeUnlocked = true;
  c.startRun(character: 'kindler', seed: seed, difficulty: difficulty);
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  return c;
}

void main() {
  test('a hard win banks a crown; the same seed on easy banks none', () {
    // Hunted 2026-08-30 with the CONTROLLER idiom on a Forge profile
    // (raw-sim playRun hunts and free-profile hunts both mislead: the
    // former diverges — v0.114.0 lesson — and the latter is silently
    // clamped to normal by clampRunParams): true hard wins 20/39.
    final hard = finishedRun('hard', seed: 20);
    expect(hard.phase, 'run_won', reason: 'seed 20 must win on hard');
    expect(hard.meta.charHardWins['kindler'], 1);
    expect(hard.meta.hardWins, 1);

    final easy = finishedRun('easy', seed: 7);
    expect(easy.phase, 'run_won');
    expect(easy.meta.charHardWins, isEmpty, reason: 'crowns are hard-only');
  });

  test('crowns survive the save round-trip and merge per-key MAX', () {
    final m = MetaState();
    expect(
      m.toJson().containsKey('charHardWins'),
      isFalse,
      reason: 'empty map stays out of the save',
    );
    m.charHardWins['kindler'] = 2;
    final back = MetaState.fromJson(m.toJson());
    expect(back.charHardWins['kindler'], 2);

    final local = MetaState()..charHardWins['kindler'] = 2;
    final cloud = MetaState()
      ..charHardWins['kindler'] = 1
      ..charHardWins['warden'] = 3;
    final merged = mergeMetaStates(local, cloud);
    expect(merged.charHardWins['kindler'], 2);
    expect(merged.charHardWins['warden'], 3);
  });

  test('delvers_crowned is junk-proof and drives both honors', () {
    final m = MetaState();
    m.charHardWins['ghost_delver'] = 99;
    expect(statValue(m, 'delvers_crowned', null), 0);
    for (final id in charactersOrder.sublist(0, 3)) {
      m.charHardWins[id] = 1;
    }
    expect(statValue(m, 'delvers_crowned', null), 3);
    expect(earnedAchievements(m), contains('three_crowns'));
    expect(earnedAchievements(m), isNot(contains('crowned_company')));
    for (final id in charactersOrder) {
      m.charHardWins[id] = 1;
    }
    expect(earnedAchievements(m), contains('crowned_company'));
  });

  test('the company promise tracks the live roster (re-pricing doctrine)', () {
    expect(achievements['crowned_company']!.target, characters.length);
    expect(
      achievements['three_crowns']!.target,
      3,
      reason: 'a fixed-count badge stays at its count',
    );
  });

  test('crown copy is honest (no pressure language)', () {
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
    for (final id in ['three_crowns', 'crowned_company']) {
      final t = '${achievements[id]!.name} ${achievements[id]!.text}'
          .toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
