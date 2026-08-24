// ignore_for_file: avoid_print
// One-off (v0.38.0): hunt bot-winnable seeds for each Trials slot so every
// trial's claim of winnability is machine-proven. Bot < human, so bot-won
// means comfortably human-possible.
import 'package:emberdelve/sim/autoplay.dart';

void hunt(String label, String ch, String diff, int asc, {int from = 1}) {
  for (var s = from; s < from + 4000; s++) {
    final r = playRun(s, character: ch, difficulty: diff, ascension: asc);
    if (r.sim.phase == 'run_won') {
      final run = r.sim.run!;
      print('$label: seed=$s $ch $diff A$asc '
          'embers=${run['embers_earned'] ?? '?'}');
      return;
    }
  }
  print('$label: NONE in range');
}

void main() {
  hunt('T1 first-steps', 'kindler', 'easy', 0);
  hunt('T2 warden-easy', 'warden', 'easy', 0, from: 7);
  hunt('T3 gambler-normal', 'gambler', 'normal', 0, from: 11);
  hunt('T4 ascetic-normal', 'ascetic', 'normal', 0, from: 3);
  hunt('T5 kindler-n-a5', 'kindler', 'normal', 5, from: 100);
  hunt('T6 warden-n-a10', 'warden', 'normal', 10, from: 200);
  hunt('T7 gambler-hard', 'gambler', 'hard', 0, from: 500);
  hunt('T8 ascetic-hard-a15', 'ascetic', 'hard', 15, from: 900);
}
