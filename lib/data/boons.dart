// data/boons.dart — starting boons for the restart flow (v4).
// CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m4-sim-contract.md §6):
//   BoonDef { id, name, text, effects }
// Effect vocabulary (exact — resolved by sim/run_layer.dart, nothing else is
// legal; a strict subset of the event-effect vocabulary):
//   gold=N        start with +N gold
//   max_hp=N      +N max hp (and +N current hp)
//   gain_die=<id> add one die to the starting pool
//   embers=N      +N embers banked into the run ledger
//
// When a new run starts with `start_run {boons:true}`, the sim offers a
// deterministic 1-of-3 pick from this table (seeded `boon` stream, without
// replacement, iterated via boonsOrder). Honest by design: the offer is shown
// in full, never expires, and skipping (index 0) is always allowed.
//
// `boonsOrder` = deterministic authoring order. Consumers that consume
// randomness iterate via boonsOrder, never map iteration order.

class BoonDef {
  final String id;
  final String name;
  final String text;
  final Map<String, Object> effects;
  const BoonDef(this.id, this.name, this.text, {required this.effects});
}

const List<String> boonsOrder = [
  'ember_purse',
  'stout_heart',
  'spare_ember',
  'keen_start',
  'ward_start',
  'lucky_charm',
  'kindled_cache',
  'steady_hand',
  // v0.3.3+ batch: widen the pool so the 1-of-3 opening offer repeats less
  // (the "delve again" hook). NOTE: growing this list reshuffles the seeded
  // boon draw — the golden anchor was deliberately re-anchored (see
  // test/sim_test.dart) when these landed.
  'brand_bearer',
  'stout_start',
  'glowing_start',
  'spark_pouch',
  'slate_guard',
  'deep_pockets',
  'hearth_blessing',
];

const Map<String, BoonDef> boons = {
  'ember_purse': BoonDef('ember_purse', 'Ember Purse',
      'Start the delve with 25 gold in hand.',
      effects: {'gold': 25}),
  'stout_heart': BoonDef('stout_heart', 'Stout Heart',
      'Start with +6 max HP.',
      effects: {'max_hp': 6}),
  'spare_ember': BoonDef('spare_ember', 'Spare Ember',
      'Add a Forged Ember (d6, +1/+1) to your starting pool.',
      effects: {'gain_die': 'd6_forged'}),
  'keen_start': BoonDef('keen_start', 'Keen Start',
      'Add a Keen Ember (d6, +1 attack) to your starting pool.',
      effects: {'gain_die': 'd6_keen'}),
  'ward_start': BoonDef('ward_start', 'Warded Start',
      'Add a Ward Iron (d6, block +2) to your starting pool.',
      effects: {'gain_die': 'd6_ward'}),
  'lucky_charm': BoonDef('lucky_charm', 'Lucky Charm',
      'Add a Charm Bone (d4, +3 on a max roll) to your starting pool.',
      effects: {'gain_die': 'd4_lucky'}),
  'kindled_cache': BoonDef('kindled_cache', 'Kindled Cache',
      'Bank 15 embers into this run\'s ledger immediately.',
      effects: {'embers': 15}),
  'steady_hand': BoonDef('steady_hand', 'Steady Hand',
      'Add a Steady Ember (d6, never rolls below 3) to your starting pool.',
      effects: {'gain_die': 'd6_steady'}),
  'brand_bearer': BoonDef('brand_bearer', 'Brand Bearer',
      'Add a Brand Iron (d6, attack only, +2 attack) to your starting pool.',
      effects: {'gain_die': 'd6_brand'}),
  'stout_start': BoonDef('stout_start', 'Stout Start',
      'Add a Stout Ember (d6, block +1) to your starting pool.',
      effects: {'gain_die': 'd6_stout'}),
  'glowing_start': BoonDef('glowing_start', 'Glowing Start',
      'Add a Glowing Ember (d6, +2 on a max roll) to your starting pool.',
      effects: {'gain_die': 'd6_ember'}),
  'spark_pouch': BoonDef('spark_pouch', 'Spark Pouch',
      'Add a Spark Chip (d4, attack only, min 2) and 10 gold.',
      effects: {'gain_die': 'd4_spark', 'gold': 10}),
  'slate_guard': BoonDef('slate_guard', 'Slate Guard',
      'Add a Slate Chip (d4, block only, min 2) and 10 gold.',
      effects: {'gain_die': 'd4_guard', 'gold': 10}),
  'deep_pockets': BoonDef('deep_pockets', 'Deep Pockets',
      'Start the delve with 40 gold in hand.',
      effects: {'gold': 40}),
  'hearth_blessing': BoonDef('hearth_blessing', 'Hearth Blessing',
      'Start with +4 max HP and bank 8 embers into the run ledger.',
      effects: {'max_hp': 4, 'embers': 8}),
};

BoonDef boonDef(String id) {
  final def = boons[id];
  if (def == null) throw ArgumentError('unknown boon id: $id');
  return def;
}
