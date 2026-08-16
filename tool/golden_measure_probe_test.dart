// tool/golden_measure_probe_test.dart — v0.22.0 golden re-anchor measurement.
// NOT part of the CI suite gate: prints candidate golden values, run twice
// per seed in-process, so the pinned numbers in test/sim_test.dart are
// measured, never guessed. Delete-or-keep policy: keep, like the sweep probes.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measure v0.22.0 goldens (8-boss anchor seeds)', () {
    for (var seed = 20260720; seed <= 20260727; seed++) {
      final a = playRun(seed).sim.eventHash;
      final b = playRun(seed).sim.eventHash;
      expect(b, equals(a), reason: 'seed $seed not reproducible');
      // ignore: avoid_print
      print('GOLDEN seed=$seed boss=${bossForSeed(seed)} hash=$a');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
