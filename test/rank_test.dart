// test/rank_test.dart — The Delver's Rank (v0.13.0).
//
// Rank is a PURE function of MetaState (meta/rank.dart): derived at read
// time, never stored. These tests pin the contract:
//   1. Tier table shape: ascending, unique, starts at 0, world-voice copy
//      passes the banned-words sweep (§Ethics).
//   2. rankFor boundaries: exactly-at-threshold holds the tier, one below
//      does not; fresh profile = tier 0; a maxed profile = top tier.
//   3. Monotone: banking more of ANY input never lowers the rank.
//   4. Cloud-merge safety: rank needs no merge rules because every input
//      survives merge as per-key MAX or set UNION — so the merged profile
//      always ranks >= both sides. This test IS the documentation.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/rank.dart';

/// §Ethics banned words — same list the trials/content sweeps use.
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

MetaState _profile({
  int wins = 0,
  int bosses = 0,
  int felled = 0,
  int met = 0,
  int codex = 0,
  int dailies = 0,
  int weeklies = 0,
}) {
  final m = MetaState();
  m.runsWon = wins;
  m.dailiesPlayed = dailies;
  m.weekliesPlayed = weeklies;
  for (var i = 0; i < bosses; i++) {
    m.bossesBeaten.add('boss_$i');
  }
  for (var i = 0; i < felled; i++) {
    m.enemyFelled['foe_$i'] = 1;
  }
  for (var i = 0; i < met; i++) {
    m.enemyMet['foe_$i'] = 1;
  }
  for (var i = 0; i < codex; i++) {
    m.ownedCodex.add('enemy:foe_$i');
  }
  return m;
}

void main() {
  test('tier table: ascending, unique ids/names, total from 0', () {
    expect(rankTiers.first.marks, 0, reason: 'every profile must hold a rank');
    for (var i = 1; i < rankTiers.length; i++) {
      expect(
        rankTiers[i].marks > rankTiers[i - 1].marks,
        isTrue,
        reason: 'thresholds must strictly ascend',
      );
    }
    expect(rankTiers.map((t) => t.id).toSet().length, rankTiers.length);
    expect(rankTiers.map((t) => t.name).toSet().length, rankTiers.length);
  });

  test('tier copy passes the banned-words sweep, dodges character names', () {
    for (final t in rankTiers) {
      final copy = '${t.name} ${t.flavor}'.toLowerCase();
      for (final word in banned) {
        expect(copy.contains(word), isFalse, reason: '"$word" in ${t.id}');
      }
      // Tier names must never read as a class change (data/ranks.dart).
      for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
        expect(t.name.toLowerCase().contains(ch), isFalse);
      }
    }
  });

  test('fresh profile holds tier 0 with 0 marks', () {
    final m = MetaState();
    expect(rankMarks(m), 0);
    expect(rankFor(m).id, rankTiers.first.id);
    expect(nextRank(m)!.id, rankTiers[1].id);
  });

  test('boundaries: at-threshold holds the tier, one mark under does not', () {
    for (var i = 1; i < rankTiers.length; i++) {
      final t = rankTiers[i];
      // Wins are 3 marks; met foes are 1 — compose exactly t.marks and
      // exactly t.marks - 1.
      final at = _profile(wins: t.marks ~/ 3, met: t.marks % 3);
      expect(rankMarks(at), t.marks);
      expect(rankFor(at).id, t.id, reason: 'at ${t.marks} marks -> ${t.id}');
      final under = _profile(
        wins: (t.marks - 1) ~/ 3,
        met: (t.marks - 1) % 3,
      );
      expect(rankMarks(under), t.marks - 1);
      expect(
        rankFor(under).id,
        rankTiers[i - 1].id,
        reason: 'one mark under ${t.id} holds the tier below',
      );
    }
  });

  test('a long, honest climb tops the ladder', () {
    // A veteran profile: hundreds of wins, full bestiary, full codex.
    final m = _profile(
      wins: 300,
      bosses: 6,
      felled: 35,
      met: 35,
      codex: 60,
      dailies: 60,
      weeklies: 20,
    );
    expect(rankFor(m).id, rankTiers.last.id);
    expect(nextRank(m), isNull, reason: 'nothing above the top tier');
  });

  test('first evening lands 2-3 rank-ups (tuning pin)', () {
    // One lost run: a handful of foes met, most felled -> already tier 1.
    final firstRun = _profile(met: 6, felled: 4);
    expect(rankFor(firstRun).id, rankTiers[1].id);
    // Evening's end: ~3 runs, one easy win, a boss down -> tier 2.
    final evening = _profile(wins: 1, bosses: 1, met: 12, felled: 9);
    expect(rankFor(evening).id, rankTiers[2].id);
  });

  test('monotone: more banked history never lowers the rank', () {
    final base = _profile(wins: 5, bosses: 1, felled: 8, met: 10, codex: 3);
    final baseMarks = rankMarks(base);
    final grown = <MetaState>[
      _profile(wins: 6, bosses: 1, felled: 8, met: 10, codex: 3),
      _profile(wins: 5, bosses: 2, felled: 8, met: 10, codex: 3),
      _profile(wins: 5, bosses: 1, felled: 9, met: 10, codex: 3),
      _profile(wins: 5, bosses: 1, felled: 8, met: 11, codex: 3),
      _profile(wins: 5, bosses: 1, felled: 8, met: 10, codex: 4),
      _profile(wins: 5, bosses: 1, felled: 8, met: 10, codex: 3, dailies: 1),
      _profile(wins: 5, bosses: 1, felled: 8, met: 10, codex: 3, weeklies: 1),
    ];
    for (final g in grown) {
      expect(rankMarks(g) > baseMarks, isTrue);
    }
  });

  test('cloud merge: derived rank never goes down (no merge rules needed)', () {
    // Device A ground the bestiary; device B won runs and dailies. Merge
    // keeps per-key MAX / set UNION, so marks(merged) >= marks(either).
    final a = _profile(wins: 2, felled: 20, met: 25, codex: 10);
    final b = _profile(wins: 12, bosses: 3, dailies: 8, met: 5);
    final merged = mergeMetaStates(a, b);
    expect(
      rankMarks(merged) >= rankMarks(a),
      isTrue,
      reason: 'merge must never outrank down vs side A',
    );
    expect(
      rankMarks(merged) >= rankMarks(b),
      isTrue,
      reason: 'merge must never outrank down vs side B',
    );
    // And the union really is a union: distinct foes from both sides count.
    expect(merged.enemyMet.length, 25);
    expect(rankFor(merged).marks >= rankFor(b).marks, isTrue);
  });
}
