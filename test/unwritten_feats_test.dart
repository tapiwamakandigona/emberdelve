// test/unwritten_feats_test.dart — v0.107.0 The Unwritten Feats.
//
// Seven achievements over the systems that grew after the ledger (weekly,
// codex, tales, settled scores, bestiary breadth). Same honesty contract as
// the originals: every stat is a real banked counter, junk-proofed where a
// catalog exists to check against, and recognition grants no power.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';

const newIds = [
  'weekly_first',
  'weekly_ten',
  'codex_ten',
  'codex_forty',
  'tales_ten',
  'score_settled',
  'twenty_names',
];

void main() {
  test('the new feats exist, use legal stats, and stay inside content', () {
    for (final id in newIds) {
      final a = achievements[id];
      expect(a, isNotNull, reason: '$id missing');
      expect(achievementsOrder, contains(id));
      expect(achievementStats, contains(a!.stat));
    }
    // Targets can never outgrow what the catalogs actually hold.
    expect(
      achievements['codex_forty']!.target,
      lessThanOrEqualTo(codexEntries.length),
    );
    expect(
      achievements['tales_ten']!.target,
      lessThanOrEqualTo(hearthTales.length),
    );
    expect(
      achievements['twenty_names']!.target,
      lessThanOrEqualTo(enemies.length),
    );
  });

  test('resolver reads the real counters', () {
    final m = MetaState();
    m.weekliesPlayed = 3;
    m.ownedCodex.addAll({'place:the_delve', 'enemy:cinder_wisp'});
    m.hearthTalesHeard = 11;
    m.settledFoes.add('quench_hag');
    expect(statValue(m, 'weeklies_played'), 3);
    expect(statValue(m, 'codex_unsealed'), 2);
    expect(statValue(m, 'tales_heard'), 11);
    expect(statValue(m, 'foes_settled'), 1);
    expect(isEarned(m, achievements['score_settled']!), isTrue);
    expect(isEarned(m, achievements['tales_ten']!), isTrue);
    expect(isEarned(m, achievements['weekly_ten']!), isFalse);
    expect(progress(m, achievements['weekly_ten']!), closeTo(0.3, 1e-9));
  });

  test('distinct_felled is junk-proof against hand-edited saves', () {
    final m = MetaState();
    final real = enemies.keys.take(3).toList();
    for (final id in real) {
      m.enemyFelled[id] = 2;
    }
    m.enemyFelled['not_an_enemy'] = 99;
    m.enemyFelled[real.first] = 0; // zero count = not felled
    expect(statValue(m, 'distinct_felled'), 2);
  });

  test('new copy passes the ethics sweep', () {
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
    for (final id in newIds) {
      final a = achievements[id]!;
      final copy = '${a.name} ${a.text}'.toLowerCase();
      for (final word in banned) {
        expect(copy.contains(word), isFalse, reason: '$id: $word');
      }
    }
  });
}
