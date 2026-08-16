// tool/boss_winrate_probe_test.dart — v0.22.0 gate: per-boss autoplay win
// rate. Fairness check for the new kings: neither slag_regent nor
// hearthless_king may sit more than 10 points outside the six incumbents'
// spread (docs/improvements/v0.22.0-crowned-deep-design.md). 100 runs per
// boss at normal/A0 defaults, seeds chosen by residue class mod 8 so every
// run provably draws the boss under test.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'per-boss win rates stay in one fair band',
    () {
      for (final difficulty in ['normal', 'hard']) {
        final rates = <String, int>{};
        for (var idx = 0; idx < 8; idx++) {
          String? boss;
          var wins = 0;
          for (var k = 0; k < 100; k++) {
            final seed = 1000 + idx + 8 * k;
            boss ??= bossForSeed(seed);
            if (playRun(seed, difficulty: difficulty).sim.phase ==
                'run_won') {
              wins++;
            }
          }
          rates[boss!] = wins;
          // ignore: avoid_print
          print('BOSSRATE $difficulty $boss $wins/100');
        }
        final incumbents = [
          'ashen_colossus',
          'ember_tyrant',
          'pyre_matriarch',
          'cinder_hierophant',
          'the_bellows',
          'ashfall_twins',
        ].map((b) => rates[b]!).toList();
        final lo = incumbents.reduce((a, b) => a < b ? a : b);
        final hi = incumbents.reduce((a, b) => a > b ? a : b);
        for (final nb in ['slag_regent', 'hearthless_king']) {
          expect(
            rates[nb]!,
            inInclusiveRange(lo - 10, hi + 10),
            reason:
                '$nb $difficulty win rate outside the incumbent spread '
                '[$lo..$hi]±10',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
