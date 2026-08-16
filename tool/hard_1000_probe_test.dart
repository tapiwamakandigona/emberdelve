// tool/hard_1000_probe_test.dart — 1000-seed HARD win rate. Written for the
// v0.22.0 gate: separates real hard-band drift from pool-remap sampling
// noise (diff SE ~2.2 points at n=1000 vs ~3.5 at n=400).
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1000-seed hard band', () {
    var wins = 0;
    for (var seed = 1; seed <= 1000; seed++) {
      if (playRun(seed, difficulty: 'hard').sim.phase == 'run_won') wins++;
    }
    // ignore: avoid_print
    print('HARD1000 ${wins / 10}%');
  }, timeout: const Timeout(Duration(minutes: 60)));
}
