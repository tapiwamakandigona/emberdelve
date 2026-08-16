// ignore_for_file: avoid_print
// One-off: find seeds where botCmd wins as kindler, boons off (matches
// tool/share_trace_visual_test.dart's controller setup).
import 'package:emberdelve/sim/autoplay.dart';

void main() {
  for (var s = 500; s < 1500; s++) {
    final r = playRun(s, character: 'kindler', boons: false);
    if (r.sim.phase == 'run_won') {
      print('WON seed=$s (kindler, normal, boons=false)');
      return;
    }
  }
  print('none in range');
}
