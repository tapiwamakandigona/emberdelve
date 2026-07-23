// bin/autoplay.dart — balance + determinism stats over N seeds.
// Usage: dart run bin/autoplay.dart [seeds]
import 'package:emberdelve/sim/autoplay.dart';

void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 200;
  var wins = 0, losses = 0, nonterminal = 0, invalids = 0;
  var maxLayerReached = 0;
  final bossKills = <int>[];
  for (var seed = 1; seed <= seeds; seed++) {
    final r = playRun(seed);
    invalids += r.invalids;
    if (r.sim.phase == 'run_won') {
      wins++;
      bossKills.add(seed);
    } else if (r.sim.phase == 'run_lost') {
      losses++;
      final layer = r.sim.run!['fights_won'] as int;
      if (layer > maxLayerReached) maxLayerReached = layer;
    } else {
      nonterminal++;
      // ignore: avoid_print
      print('NONTERMINAL seed=$seed phase=${r.sim.phase} applied=${r.applied}');
    }
  }
  // determinism: twin snapshot check on 1..20
  var twinFails = 0;
  for (var seed = 1; seed <= 20; seed++) {
    final a = playRun(seed);
    final b = playRun(seed, snapAt: 30);
    if (a.sim.eventHash != b.sim.eventHash ||
        a.sim.stateHash() != b.sim.stateHash()) {
      twinFails++;
    }
  }
  // self-consistency golden
  final g1 = playRun(20260723).sim.eventHash;
  final g2 = playRun(20260723).sim.eventHash;
  final pct = (wins * 100 / seeds).toStringAsFixed(1);
  // ignore: avoid_print
  print('seeds=$seeds wins=$wins losses=$losses nonterminal=$nonterminal '
      'winrate=$pct% invalids=$invalids twinFails=$twinFails');
  // ignore: avoid_print
  print('golden(20260723)=$g1 selfconsistent=${g1 == g2}');
}
