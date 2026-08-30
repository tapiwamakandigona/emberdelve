// test/fifteenth_rung_test.dart — v0.143.0 The Fifteenth Rung.
//
// The ascension ladder's provings ran 5/10 while the badges run 3/10/20 —
// the 15th rung closes the gap. Same contracts as every rung proving.
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the rung stands between the tenth and the high stakes', () {
    final p = provingById('fifteenth_rung')!;
    expect(p.ascension, 15);
    expect(p.difficulty, 'normal');
    expect(p.character, 'kindler');
    expect(p.seed, 14);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('fifteenth_rung'),
      ids.indexOf('tenth_rung') + 1,
      reason: 'the rung provings stand together, in climb order',
    );
    expect(provings.last.id, 'ash_summit');
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(14, ascension: 15, difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('rung copy is honest (no pressure language)', () {
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
    final p = provingById('fifteenth_rung')!;
    final t = '${p.title} ${p.blurb}'.toLowerCase();
    for (final b in banned) {
      expect(t.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
