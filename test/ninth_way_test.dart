// test/ninth_way_test.dart — v0.146.0 The Ninth Way.
//
// The bearer's proving (the v0.119 pattern, third use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the bearer's proving stands with the delver provings", () {
    final p = provingById('bearers_proving')!;
    expect(p.character, 'bearer');
    expect(p.difficulty, 'normal');
    expect(p.seed, 8);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('bearers_proving'),
      ids.indexOf('runesmiths_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(8, character: 'bearer', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the ninth honors follow the v0.119 pattern', () {
    final wins = achievements['bearer_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'bearer');
    expect(wins.target, 1);
    final nine = achievements['nine_ways_down']!;
    expect(nine.stat, 'delvers_cleared');
    expect(nine.target, 9);
    // The frozen predecessors kept their earned prices.
    expect(achievements['eight_ways_down']!.target, 8);
    expect(achievements['seven_ways_down']!.target, 7);
  });
}
