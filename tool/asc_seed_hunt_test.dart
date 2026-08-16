import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first A20 winning seeds per character', () {
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      final wins = <int>[];
      for (var seed = 1; seed <= 400 && wins.length < 3; seed++) {
        final r = playRun(seed, character: ch, difficulty: 'hard', ascension: 20);
        if (r.sim.phase == 'run_won') wins.add(seed);
      }
      // ignore: avoid_print
      print('$ch A20 winning seeds: $wins');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
