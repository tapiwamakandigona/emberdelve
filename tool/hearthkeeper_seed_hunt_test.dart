import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hearthkeeper seed hunt', () {
    for (final diff in ['easy', 'normal']) {
      final wins = <int>[], losses = <int>[];
      for (var s = 1; s <= 14; s++) {
        final r = playRun(s, character: 'hearthkeeper', difficulty: diff);
        (r.sim.phase == 'run_won' ? wins : losses).add(s);
      }
      // ignore: avoid_print
      print('$diff wins=$wins losses=$losses');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
