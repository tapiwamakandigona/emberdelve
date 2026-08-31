// test/kept_hearth_test.dart — The Kept Hearth.
//
// The hearthkeeper's proving (the v0.119 pattern, tenth use: the delver
// ships, then their proving and roster honors follow under NEW names —
// the historical honors never re-price). This is the LAST delver proving:
// the roster is closed at sixteen, so the delver-proving block is complete.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the hearthkeeper's proving stands last among the delver provings",
      () {
    final p = provingById('hearthkeepers_proving')!;
    expect(p.character, 'hearthkeeper');
    expect(p.difficulty, 'normal');
    expect(p.seed, 16, reason: 'seed sixteen for the sixteenth chair');
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('hearthkeepers_proving'),
      ids.indexOf('stokers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(16, character: 'hearthkeeper', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the sixteenth honors follow the v0.119 pattern', () {
    final wins = achievements['hearthkeeper_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'hearthkeeper');
    expect(wins.target, 1);
    final sixteen = achievements['sixteen_ways_down']!;
    expect(sixteen.stat, 'delvers_cleared');
    expect(sixteen.target, 16);
    // The frozen predecessors kept their earned prices.
    expect(achievements['fifteen_ways_down']!.target, 15);
    expect(achievements['fourteen_ways_down']!.target, 14);
  });
}
