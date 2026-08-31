import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shieldwright seed hunt', () {
    for (final diff in ['easy', 'normal']) {
      final wins = <int>[], losses = <int>[];
      for (var seed = 1; seed <= 12; seed++) {
        final r = playRun(seed, character: 'shieldwright', difficulty: diff);
        (r.sim.phase == 'run_won' ? wins : losses).add(seed);
      }
      // ignore: avoid_print
      print('$diff wins=$wins losses=$losses');
    }
  });
}
