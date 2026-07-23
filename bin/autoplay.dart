// bin/autoplay.dart — balance + determinism stats over N seeds.
// Usage: dart run bin/autoplay.dart [seeds] [easy|normal|hard]
// v0.3.3: optional difficulty arg + loss histogram by fights-won, so the
// "where do players die" shape (first-fight wall vs staircase) is observable.
import 'package:emberdelve/sim/autoplay.dart';

void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 200;
  final difficulty = args.length > 1 ? args[1] : 'normal';
  var wins = 0, losses = 0, nonterminal = 0, invalids = 0;
  var maxLayerReached = 0;
  var embersTotal = 0;
  final bossKills = <int>[];
  final deathsByFightsWon = <int, int>{};
  for (var seed = 1; seed <= seeds; seed++) {
    final r = playRun(seed, difficulty: difficulty);
    invalids += r.invalids;
    embersTotal += r.sim.run?['embers'] as int? ?? 0;
    if (r.sim.phase == 'run_won') {
      wins++;
      bossKills.add(seed);
    } else if (r.sim.phase == 'run_lost') {
      losses++;
      final layer = r.sim.run!['fights_won'] as int;
      deathsByFightsWon[layer] = (deathsByFightsWon[layer] ?? 0) + 1;
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
  print('difficulty=$difficulty seeds=$seeds wins=$wins losses=$losses '
      'nonterminal=$nonterminal winrate=$pct% invalids=$invalids '
      'twinFails=$twinFails');
  // ignore: avoid_print
  print('avgEmbers=${(embersTotal / seeds).toStringAsFixed(1)}');
  if (losses > 0) {
    final keys = deathsByFightsWon.keys.toList()..sort();
    final hist =
        keys.map((k) => '$k:${deathsByFightsWon[k]}').join(' ');
    final firstFight = deathsByFightsWon[0] ?? 0;
    final share = (firstFight * 100 / losses).toStringAsFixed(1);
    // ignore: avoid_print
    print('deathsByFightsWon: $hist (first-fight share $share%)');
  }
  // ignore: avoid_print
  print('golden(20260723)=$g1 selfconsistent=${g1 == g2}');
}
