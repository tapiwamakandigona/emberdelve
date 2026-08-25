// tool/tinker_proving_hunt_test.dart — v0.52.0 seed hunt: bot-winnable
// tinker NORMAL seeds in 100..200 (a proving wants its own dedicated seed,
// away from the pin tables). Also prints hard results for a stretch option.
// Not part of CI.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tinker proving hunt', () {
    for (final diff in ['normal', 'hard']) {
      final wins = <int>[];
      for (var seed = 100; seed <= 200; seed++) {
        final r = playRun(seed, character: 'tinker', difficulty: diff);
        if (r.sim.phase == 'run_won') wins.add(seed);
      }
      // ignore: avoid_print
      print('tinker/$diff wins 100..200: $wins');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
