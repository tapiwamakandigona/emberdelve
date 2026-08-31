// test/eleventh_way_test.dart — v0.159.0 The Eleventh Way.
//
// The shieldwright's proving (the v0.119 pattern, fifth use: the delver
// ships, then their proving and roster honors follow under NEW names —
// the historical honors never re-price).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the shieldwright's proving stands with the delver provings", () {
    final p = provingById('shieldwrights_proving')!;
    expect(p.character, 'shieldwright');
    expect(p.difficulty, 'normal');
    expect(p.seed, 10);
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('shieldwrights_proving'),
      ids.indexOf('menders_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(10, character: 'shieldwright', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the eleventh honors follow the v0.119 pattern', () {
    final wins = achievements['shieldwright_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'shieldwright');
    expect(wins.target, 1);
    final eleven = achievements['eleven_ways_down']!;
    expect(eleven.stat, 'delvers_cleared');
    expect(eleven.target, 11);
    // The frozen predecessors kept their earned prices.
    expect(achievements['ten_ways_down']!.target, 10);
    expect(achievements['nine_ways_down']!.target, 9);
  });
}
