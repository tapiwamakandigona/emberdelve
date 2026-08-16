// tool/balance_sweep_probe.dart — v0.17.0 candidate research: measures the
// live balance surface (character x difficulty win rates, loss-floor
// distribution) so a balance pass is data-driven, not vibes-driven.
//
// Run:  flutter test tool/balance_sweep_probe.dart --reporter expanded
//
// Probe only — asserts termination; fairness gates live in test/.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('balance sweep: character x difficulty', () {
    const seeds = 150;
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      for (final diff in ['easy', 'normal', 'hard']) {
        var wins = 0;
        final lossFloors = <int>[];
        for (var seed = 1; seed <= seeds; seed++) {
          final r = playRun(seed, character: ch, difficulty: diff);
          if (r.sim.phase == 'run_won') {
            wins++;
          } else {
            final f = (r.sim.state['map'] as Map?)?['floor'];
            lossFloors.add(f is int ? f : -1);
          }
        }
        lossFloors.sort();
        final med = lossFloors.isEmpty
            ? '-'
            : '${lossFloors[lossFloors.length ~/ 2]}';
        // ignore: avoid_print
        print(
          '$ch/$diff: ${(wins * 100 / seeds).toStringAsFixed(1)}% win '
          '(median loss floor $med, n=${lossFloors.length})',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
