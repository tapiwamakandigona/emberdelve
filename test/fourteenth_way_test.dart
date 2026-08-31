// test/fourteenth_way_test.dart — v0.172.0 The Fourteenth Way.
//
// The collier's proving (the v0.119 pattern, eighth use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the collier's proving stands with the delver provings", () {
    final p = provingById('colliers_proving')!;
    expect(p.character, 'collier');
    expect(p.difficulty, 'normal');
    expect(p.seed, 6);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('colliers_proving'),
      ids.indexOf('cutlers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(6, character: 'collier', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the fourteenth honors follow the v0.119 pattern', () {
    final wins = achievements['collier_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'collier');
    expect(wins.target, 1);
    final fourteen = achievements['fourteen_ways_down']!;
    expect(fourteen.stat, 'delvers_cleared');
    expect(fourteen.target, 14);
    // The frozen predecessors kept their earned prices.
    expect(achievements['thirteen_ways_down']!.target, 13);
    expect(achievements['twelve_ways_down']!.target, 12);
  });
}
