// test/autoplay_test.dart — the balance + integrity gate.
// A deterministic greedy bot plays 200 seeded runs; asserts every run
// terminates without the bot ever emitting an invalid command, the win rate
// lands in the 20–80% fair-balance band, and the ascension ladder makes the
// game monotonically harder.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/sim/autoplay.dart';

void main() {
  test('200 seeded runs terminate cleanly with no invalid commands', () {
    var invalids = 0;
    for (var seed = 1; seed <= 200; seed++) {
      final r = playRun(seed);
      expect(['run_won', 'run_lost'].contains(r.sim.phase), isTrue,
          reason: 'seed $seed non-terminal (${r.sim.phase})');
      invalids += r.invalids;
    }
    expect(invalids, equals(0));
  });

  test('win rate is inside the 20%-80% fair-balance band', () {
    var wins = 0;
    for (var seed = 1; seed <= 200; seed++) {
      if (playRun(seed).sim.phase == 'run_won') wins++;
    }
    final pct = wins * 100 / 200;
    expect(pct, inInclusiveRange(20, 80), reason: 'win rate $pct%');
  });

  test('ascension makes the run strictly harder (win rate falls)', () {
    int winsAt(int asc) {
      var w = 0;
      for (var seed = 1; seed <= 120; seed++) {
        if (playRun(seed, ascension: asc).sim.phase == 'run_won') w++;
      }
      return w;
    }
    final a0 = winsAt(0);
    final a6 = winsAt(6);
    expect(a6, lessThan(a0), reason: 'asc6 ($a6) not harder than asc0 ($a0)');
  });
}
