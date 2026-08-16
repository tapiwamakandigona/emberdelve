// tool/golden_boss_reach_probe_test.dart — v0.22.0: verify each candidate
// anchor seed's autoplay run actually FIGHTS its boss (a per-boss golden that
// dies on layer 4 pins nothing about that boss; event type is encounter_started). Drives the same greedy bot
// as playRun but captures the event stream to look for the boss combat_begin.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

bool metBoss(int seed, String boss) {
  final sim = Sim(seed);
  var met = false;
  for (var i = 0; i < 4000; i++) {
    final cmd = botCmd(sim);
    if (cmd == null) break;
    for (final ev in sim.apply(cmd)) {
      if (ev['type'] == 'encounter_started' && ev['enemy'] == boss) met = true;
    }
  }
  return met;
}

void main() {
  test('boss reach per anchor candidate', () {
    for (var base = 20260720; base <= 20260727; base++) {
      for (var k = 0; k < 8; k++) {
        final seed = base + 8 * k;
        final boss = bossForSeed(seed);
        final met = metBoss(seed, boss);
        final r = playRun(seed);
        // ignore: avoid_print
        print(
          'REACH seed=$seed boss=$boss met=$met phase=${r.sim.phase} '
          'hash=${r.sim.eventHash}',
        );
        if (met) break;
      }
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
