// tool/ascension_sweep_probe.dart — v0.20.0 candidate research: measures the
// ascension ladder (character x ascension rung win rates on hard, loss-floor
// medians) so any ascension balance pass is data-driven, not vibes-driven.
//
// Run:  flutter test tool/ascension_sweep_probe.dart --reporter expanded
//
// Probe only — asserts termination; fairness gates live in test/.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ascension sweep: character x rung (hard)', () {
    const seeds = 100;
    const rungs = [1, 3, 5, 8, 12, 16, 20];
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      for (final asc in rungs) {
        var wins = 0;
        final lossFloors = <int>[];
        for (var seed = 1; seed <= seeds; seed++) {
          final r = playRun(
            seed,
            character: ch,
            difficulty: 'hard',
            ascension: asc,
          );
          if (r.sim.phase == 'run_won') {
            wins++;
          } else {
            final map = r.sim.state()['map'] as Map?;
            final node = ((map?['nodes'] as Map?) ?? {})['${map?['position']}'];
            final f = (node as Map?)?['layer'];
            lossFloors.add(f is int ? f : -1);
          }
        }
        lossFloors.sort();
        final med = lossFloors.isEmpty
            ? '-'
            : '${lossFloors[lossFloors.length ~/ 2]}';
        // ignore: avoid_print
        print(
          '$ch/A$asc: ${(wins * 100 / seeds).toStringAsFixed(1)}% win '
          '(median loss floor $med, n=${lossFloors.length})',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
