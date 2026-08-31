// test/tenth_way_test.dart — v0.151.0 The Tenth Way.
//
// The mender's proving (the v0.119 pattern, fourth use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the mender's proving stands with the delver provings", () {
    final p = provingById('menders_proving')!;
    expect(p.character, 'mender');
    expect(p.difficulty, 'normal');
    expect(p.seed, 9);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('menders_proving'),
      ids.indexOf('bearers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(9, character: 'mender', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the tenth honors follow the v0.119 pattern', () {
    final wins = achievements['mender_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'mender');
    expect(wins.target, 1);
    final ten = achievements['ten_ways_down']!;
    expect(ten.stat, 'delvers_cleared');
    expect(ten.target, 10);
    // The frozen predecessors kept their earned prices.
    expect(achievements['nine_ways_down']!.target, 9);
    expect(achievements['eight_ways_down']!.target, 8);
  });
}
