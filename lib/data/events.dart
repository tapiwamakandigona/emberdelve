// data/events.dart — Emberdelve event deck (M3 content: 16 events).
// CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m3-contract.md §7):
//   EventDef { id, name, text, options: [OptionDef { label, effects }] }
// Effect vocabulary (exact — applied by sim/run_layer.dart in EFFECT ORDER,
// nothing else is legal). All amounts are ints:
//   gold=±N            gain/pay gold (an option needing gold the player lacks
//                      is an invalid command — state untouched)
//   gold_after=+N      gold paid out AFTER the gold cost resolves (bet payout)
//   hp=±N              damage floors at 1 hp (events never kill — fair-death
//                      pillar: only fights end runs); heals cap at max
//   max_hp=±N          floor 10; current hp clamped
//   embers=+N          meta payout, added to the run ledger
//   heal_pct=N         heal N% of max hp (integer floor)
//   gain_die=<id>      add this exact die to the pool
//   gain_random_die=T  random die of tier <= T via the loot stream
//   lose_random_die=1  lose a random die via the shuffle stream (only valid
//                      while pool > 3)
//   gain_random_relic=1  random unowned relic via the loot stream
//                        (falls back to embers=+15 when all are owned)
//
// Event pick at node entry: uniform over events not yet seen this run
// (shuffle stream); repeats allowed only once the whole deck was seen.
// `eventsOrder` lists every id in deterministic authoring order.

class OptionDef {
  final String label;
  final Map<String, Object> effects;
  const OptionDef(this.label, this.effects);
}

class EventDef {
  final String id;
  final String name;
  final String text;
  final List<OptionDef> options;
  const EventDef(this.id, this.name, this.text, this.options);
}

const List<String> eventsOrder = [
  'abandoned_forge', 'ember_shrine', 'collapsed_tunnel', 'wandering_peddler',
  'dice_ghost', 'molten_spring', 'beggar_wisp', 'cracked_geode',
  'old_delver', 'ash_garden', 'tyrants_echo', 'gamblers_table',
  'sealed_vault', 'ember_moths', 'broken_cart', 'whispering_coals',
];

const Map<String, EventDef> events = {
  'abandoned_forge': EventDef(
      'abandoned_forge',
      'Abandoned Forge',
      'A cold forge, tools still hanging. Someone left in a hurry.',
      [
        OptionDef('Work the forge (gain a random die)', {'gain_random_die': 2}),
        OptionDef('Scavenge for coins (+25 gold)', {'gold': 25}),
        OptionDef('Move on', {}),
      ]),
  'ember_shrine': EventDef(
      'ember_shrine',
      'Ember Shrine',
      'A shrine of warm stone. Offerings crumble to ash around it.',
      [
        OptionDef('Offer 20 gold (+18 embers)', {'gold': -20, 'embers': 18}),
        OptionDef('Pray quietly (heal 25%)', {'heal_pct': 25}),
        OptionDef('Move on', {}),
      ]),
  'collapsed_tunnel': EventDef(
      'collapsed_tunnel',
      'Collapsed Tunnel',
      'The short way down is buried. You can dig, or squeeze the crack.',
      [
        OptionDef('Dig through (-6 hp, +30 gold)', {'hp': -6, 'gold': 30}),
        OptionDef('Squeeze past (safe)', {}),
      ]),
  'wandering_peddler': EventDef(
      'wandering_peddler',
      'Wandering Peddler',
      'A hooded figure rattles a sack of oddities. "Cheap. Ish."',
      [
        OptionDef('Buy a mystery die (35 gold)',
            {'gold': -35, 'gain_random_die': 3}),
        OptionDef('Buy a trinket (60 gold)',
            {'gold': -60, 'gain_random_relic': 1}),
        OptionDef('Decline', {}),
      ]),
  'dice_ghost': EventDef(
      'dice_ghost',
      'Dice Ghost',
      'A translucent gambler blocks the path. "One of yours... for one of mine."',
      [
        OptionDef('Trade (lose a random die, gain a random die)',
            {'lose_random_die': 1, 'gain_random_die': 3}),
        OptionDef('Refuse', {}),
      ]),
  'molten_spring': EventDef(
      'molten_spring',
      'Molten Spring',
      'Water hisses over glowing rock. It smells of iron and heat.',
      [
        OptionDef('Bathe (heal 40%)', {'heal_pct': 40}),
        OptionDef('Temper yourself (-5 hp now, +4 max hp)',
            {'hp': -5, 'max_hp': 4}),
      ]),
  'beggar_wisp': EventDef(
      'beggar_wisp',
      'Beggar Wisp',
      'A dim wisp flickers weakly, drawn to your coin pouch.',
      [
        OptionDef('Give 15 gold (+12 embers)', {'gold': -15, 'embers': 12}),
        OptionDef('Shoo it away', {}),
      ]),
  'cracked_geode': EventDef(
      'cracked_geode',
      'Cracked Geode',
      'A geode the size of a barrel, split just enough to reach inside.',
      [
        OptionDef('Reach in (-4 hp, +40 gold)', {'hp': -4, 'gold': 40}),
        OptionDef('Chip at it safely (+15 gold)', {'gold': 15}),
      ]),
  'old_delver': EventDef(
      'old_delver',
      'Old Delver',
      'A retired delver warms her hands. "Down there, steel beats luck."',
      [
        OptionDef('Trade stories (gain a d6 Forged Ember)',
            {'gain_die': 'd6_forged'}),
        OptionDef('Share supplies (-10 gold, heal 30%)',
            {'gold': -10, 'heal_pct': 30}),
        OptionDef('Nod and pass', {}),
      ]),
  'ash_garden': EventDef(
      'ash_garden',
      'Ash Garden',
      'Grey flowers that bloom only underground. Beautiful. Poisonous.',
      [
        OptionDef('Pick a bloom (-3 hp, +14 embers)', {'hp': -3, 'embers': 14}),
        OptionDef('Admire and move on', {}),
      ]),
  'tyrants_echo': EventDef(
      'tyrants_echo',
      "Tyrant's Echo",
      'The walls rumble with a voice from below: "TURN. BACK."',
      [
        OptionDef('Steel yourself (+3 max hp)', {'max_hp': 3}),
        OptionDef('Hurry past (safe)', {}),
      ]),
  'gamblers_table': EventDef(
      'gamblers_table',
      "Gambler's Table",
      'Skeletal hands shuffle bone dice. A seat waits, dusted clean.',
      [
        OptionDef('Bet 25 gold (win a random relic)',
            {'gold': -25, 'gain_random_relic': 1}),
        OptionDef('Bet 10 gold (+22 gold back)', {'gold': -10, 'gold_after': 22}),
        OptionDef('Walk away', {}),
      ]),
  'sealed_vault': EventDef(
      'sealed_vault',
      'Sealed Vault',
      'A vault door, warm to the touch. The lock is half melted.',
      [
        OptionDef('Force it (-8 hp, gain a random relic)',
            {'hp': -8, 'gain_random_relic': 1}),
        OptionDef('Leave it sealed', {}),
      ]),
  'ember_moths': EventDef(
      'ember_moths',
      'Ember Moths',
      'A cloud of glowing moths settles on your pack, drawn to the embers.',
      [
        OptionDef('Let them feed (+8 embers)', {'embers': 8}),
        OptionDef('Wave them off', {}),
      ]),
  'broken_cart': EventDef(
      'broken_cart',
      'Broken Cart',
      "A supply cart, wheel shattered. Its owner won't be back.",
      [
        OptionDef('Take supplies (heal 20%, +12 gold)',
            {'heal_pct': 20, 'gold': 12}),
        OptionDef('Leave it for someone else (+6 embers)', {'embers': 6}),
      ]),
  'whispering_coals': EventDef(
      'whispering_coals',
      'Whispering Coals',
      'Coals spell out words when you stop looking directly at them.',
      [
        OptionDef('Listen (gain a random die of any tier)',
            {'gain_random_die': 3}),
        OptionDef('Scatter the coals (+10 gold)', {'gold': 10}),
      ]),
};

EventDef eventDef(String id) {
  final def = events[id];
  if (def == null) throw ArgumentError('unknown event id: $id');
  return def;
}
