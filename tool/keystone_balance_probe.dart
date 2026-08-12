// tool/keystone_balance_probe.dart — measures what the v7 keystone actually
// does to the difficulty curve, and prints the golden anchors that a
// deliberate re-anchor must record.
//
// Run:  flutter test tool/keystone_balance_probe.dart --reporter expanded
//
// It is a test file only so it can use the flutter_test runner; it asserts
// nothing beyond termination. The gates live in test/autoplay_test.dart.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

int _winsOver(int seeds, {int ascension = 0, bool keystones = true}) {
  var wins = 0;
  for (var seed = 1; seed <= seeds; seed++) {
    if (playRun(seed, ascension: ascension, keystones: keystones).sim.phase ==
        'run_won') {
      wins++;
    }
  }
  return wins;
}

void main() {
  test('keystone balance + golden anchors', () {
    const seeds = 200;
    final taking = _winsOver(seeds);
    final declining = _winsOver(seeds, keystones: false);
    // ignore: avoid_print
    print('win rate, keystone taken:    ${taking * 100 / seeds}%');
    // ignore: avoid_print
    print('win rate, keystone declined: ${declining * 100 / seeds}%');

    for (final asc in [0, 3, 6, 12, 20]) {
      final w = _winsOver(120, ascension: asc);
      // ignore: avoid_print
      print('ascension $asc: ${w * 100 / 120}% over 120 seeds');
    }

    final anchor = playRun(20260723);
    // ignore: avoid_print
    print(
      'golden anchor 20260723: eventHash=${anchor.sim.eventHash} '
      'events=${anchor.sim.eventCount} phase=${anchor.sim.phase}',
    );
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final r = playRun(seed);
      // ignore: avoid_print
      print('seed $seed: eventHash=${r.sim.eventHash} phase=${r.sim.phase}');
    }
  });
}
