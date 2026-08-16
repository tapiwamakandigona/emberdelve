import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A20 loss-floor histogram', () {
    for (final ch in ['warden', 'ascetic', 'kindler', 'gambler']) {
      final hist = <int, int>{};
      for (var seed = 1; seed <= 100; seed++) {
        final r = playRun(seed, character: ch, difficulty: 'hard', ascension: 20);
        if (r.sim.phase != 'run_won') {
          final map = r.sim.state()['map'] as Map?;
          final node = ((map?['nodes'] as Map?) ?? {})['${map?['position']}'];
          final f = (node as Map?)?['layer'];
          hist[f is int ? f : -1] = (hist[f is int ? f : -1] ?? 0) + 1;
        }
      }
      final keys = hist.keys.toList()..sort();
      // ignore: avoid_print
      print('$ch/A20 losses by floor: ${[for (final k in keys) '$k:${hist[k]}'].join(' ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
