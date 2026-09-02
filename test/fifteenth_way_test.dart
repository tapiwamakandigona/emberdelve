// test/fifteenth_way_test.dart — v0.176.0 The Fifteenth Way.
//
// The stoker's proving (the v0.119 pattern, ninth use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the stoker's proving stands with the delver provings", () {
    final p = provingById('stokers_proving')!;
    expect(p.character, 'stoker');
    expect(p.difficulty, 'normal');
    expect(p.seed, 14); // v0.180.0 re-anchor: 12 -> 14
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('stokers_proving'),
      ids.indexOf('colliers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(14, character: 'stoker', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the fifteenth honors follow the v0.119 pattern', () {
    final wins = achievements['stoker_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'stoker');
    expect(wins.target, 1);
    final fifteen = achievements['fifteen_ways_down']!;
    expect(fifteen.stat, 'delvers_cleared');
    expect(fifteen.target, 15);
    // The frozen predecessors kept their earned prices.
    expect(achievements['fourteen_ways_down']!.target, 14);
    expect(achievements['thirteen_ways_down']!.target, 13);
  });
}
