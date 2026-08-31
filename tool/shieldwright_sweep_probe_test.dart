// tool/shieldwright_sweep_probe_test.dart — v0.158.0 balance probe: Shieldwright bot
// winrate x difficulty over 400 seeds, vs Kindler baseline. Not part of CI.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shieldwright sweep', () {
    const seeds = 400;
    for (final ch in ['shieldwright', 'kindler']) {
      for (final diff in ['easy', 'normal', 'hard']) {
        var wins = 0;
        for (var seed = 1; seed <= seeds; seed++) {
          final r = playRun(seed, character: ch, difficulty: diff);
          if (r.sim.phase == 'run_won') wins++;
        }
        // ignore: avoid_print
        print('$ch/$diff: ${(wins * 100 / seeds).toStringAsFixed(2)}%');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
