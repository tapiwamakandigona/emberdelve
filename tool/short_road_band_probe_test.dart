// tool/short_road_band_probe_test.dart — v0.49.0 gate probe (temp).
// 400-seed win-rate bands for the Short Delve (mutators: [short_road]) per
// difficulty, defaults A0. Bands must hold: easy 80-90 / normal 55-70 /
// hard 30-45. Delete after the gate decision is recorded in the design doc.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short road 400-seed bands', () {
    for (final d in ['easy', 'normal', 'hard']) {
      var wins = 0;
      for (var seed = 1; seed <= 400; seed++) {
        final r = playRun(seed, difficulty: d, mutators: const ['short_road']);
        if (r.sim.phase == 'run_won') wins++;
      }
      // ignore: avoid_print
      print('SHORT400 $d ${wins / 4}%');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
