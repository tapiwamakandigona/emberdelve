// test/taught_fire_test.dart — v0.148.0 The Taught Fire.
//
// The fair-death pillar finally teaches the anvil: two insight lines
// (mid: go temper; late: what an Aegis mark buys). Plus the pin the
// whole catalog never had — every death line held to the §Ethics
// banned-word charter, same as tales, news, and codex before it.
import 'package:emberdelve/data/insights.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the anvil speaks in its buckets', () {
    expect(
      insights['mid']!.any((l) => l.contains('anvil')),
      isTrue,
      reason: 'mid deaths (layers 4-6) are where rests start mattering',
    );
    expect(
      insights['late']!.any((l) => l.contains('Aegis mark')),
      isTrue,
      reason: 'late deaths are elite prep lessons',
    );
  });

  test('the mid line tells the truth: a mark pays every floor after', () {
    final sim = Sim(6)..apply({'type': 'start_run', 'character': 'kindler'});
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'blade'});
    // The mark lives in run state, not floor state — it survives the delve.
    final id = (sim.player['dice'] as List).cast<String>()[0];
    final resolved = resolveRunDie(sim.run, id);
    expect(resolved.rune, 'blade');
    expect(resolved.temperedFace, 2);
  });

  test('every death line holds the ethics charter', () {
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
    const core = {'early', 'mid', 'late', 'boss', 'generic'};
    expect(insights.keys.toSet().containsAll(core), isTrue);
    for (final k in insights.keys) {
      expect(
        core.contains(k) || k.startsWith('boss_'),
        isTrue,
        reason: 'unexpected bucket $k',
      );
    }
    for (final bucket in insights.entries) {
      expect(bucket.value, isNotEmpty);
      for (final line in bucket.value) {
        final t = line.toLowerCase();
        for (final b in banned) {
          expect(
            t.contains(b),
            isFalse,
            reason: '"$b" in ${bucket.key}: $line',
          );
        }
      }
    }
  });
}
