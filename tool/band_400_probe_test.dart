// tool/band_400_probe_test.dart — 400-seed difficulty bands (defaults, A0).
// Written for the v0.22.0 gate: the 120-seed sweep showed hard 41% vs 45-50%
// at v0.21.0, which is within sampling noise (SE of the diff ~6.4 points at
// n=120); this probe decides with n=400 per difficulty (SE ~2.5).
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('400-seed bands', () {
    for (final d in ['easy', 'normal', 'hard']) {
      var wins = 0;
      for (var seed = 1; seed <= 400; seed++) {
        if (playRun(seed, difficulty: d).sim.phase == 'run_won') wins++;
      }
      // ignore: avoid_print
      print('BAND400 $d ${wins / 4}%');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
