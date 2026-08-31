// test/thirteenth_way_test.dart — v0.170.0 The Thirteenth Way.
//
// The cutler's proving (the v0.119 pattern, seventh use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the cutler's proving stands with the delver provings", () {
    final p = provingById('cutlers_proving')!;
    expect(p.character, 'cutler');
    expect(p.difficulty, 'normal');
    expect(p.seed, 14);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('cutlers_proving'),
      ids.indexOf('gilders_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(14, character: 'cutler', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the thirteenth honors follow the v0.119 pattern', () {
    final wins = achievements['cutler_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'cutler');
    expect(wins.target, 1);
    final thirteen = achievements['thirteen_ways_down']!;
    expect(thirteen.stat, 'delvers_cleared');
    expect(thirteen.target, 13);
    // The frozen predecessors kept their earned prices.
    expect(achievements['twelve_ways_down']!.target, 12);
    expect(achievements['eleven_ways_down']!.target, 11);
  });
}
