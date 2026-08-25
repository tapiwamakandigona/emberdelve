// tool/peddler_sweep_probe_test.dart — roster balance probe (v0.40.0): bot
// winrate per character x difficulty over 150 seeds. Not part of CI.
// v0.40.0 result (simVersion 7): warden 92.7/80.0/56.0, kindler 89.3/70.0/38.0,
// ascetic 88.7/58.7/30.0, gambler 87.3/58.0/35.3, peddler 88.0/58.7/28.7 —
// the Peddler lands with the skill delvers, fitting the priciest unlock.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('peddler sweep', () {
    const seeds = 150;
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic', 'peddler']) {
      for (final diff in ['easy', 'normal', 'hard']) {
        var wins = 0;
        for (var seed = 1; seed <= seeds; seed++) {
          final r = playRun(seed, character: ch, difficulty: diff);
          if (r.sim.phase == 'run_won') wins++;
        }
        // ignore: avoid_print
        print('$ch/$diff: ${(wins * 100 / seeds).toStringAsFixed(1)}%');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
