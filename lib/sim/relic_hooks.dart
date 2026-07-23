// sim/relic_hooks.dart — additive relic-hook aggregation.
// SEALED SIM MODULE: pure Dart. Reads the owned relic ids on sim.run and sums
// a hook value across all of them (data/relics.dart hook vocabulary). Iterated
// in relicsOrder for determinism (though addition is order-free).

import '../data/relics.dart';
import 'sim.dart';

int relicSum(Sim sim, String hook) {
  final run = sim.run;
  if (run == null) return 0;
  final owned = (run['relics'] as List?)?.cast<String>() ?? const [];
  if (owned.isEmpty) return 0;
  var total = 0;
  for (final id in relicsOrder) {
    if (owned.contains(id)) {
      total += relics[id]!.hooks[hook] ?? 0;
    }
  }
  return total;
}

bool ownsRelic(Sim sim, String id) {
  final owned = (sim.run?['relics'] as List?)?.cast<String>() ?? const [];
  return owned.contains(id);
}
