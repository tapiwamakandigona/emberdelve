// test/twelfth_way_test.dart — v0.163.0 The Twelfth Way.
//
// The gilder's proving (the v0.119 pattern, sixth use: the delver ships,
// then their proving and roster honors follow under NEW names — the
// historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the gilder's proving stands with the delver provings", () {
    final p = provingById('gilders_proving')!;
    expect(p.character, 'gilder');
    expect(p.difficulty, 'normal');
    expect(p.seed, 4);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('gilders_proving'),
      ids.indexOf('shieldwrights_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(4, character: 'gilder', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the twelfth honors follow the v0.119 pattern', () {
    final wins = achievements['gilder_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'gilder');
    expect(wins.target, 1);
    final twelve = achievements['twelve_ways_down']!;
    expect(twelve.stat, 'delvers_cleared');
    expect(twelve.target, 12);
    // The frozen predecessors kept their earned prices.
    expect(achievements['eleven_ways_down']!.target, 11);
    expect(achievements['ten_ways_down']!.target, 10);
  });
}
