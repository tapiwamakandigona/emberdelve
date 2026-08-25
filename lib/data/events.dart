// data/events.dart — Emberdelve event deck (v0.46.0: 45 events).
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
  // v0.5.0 additions. Deck size drives how long a run stays surprising: the
  // pick is uniform over events NOT yet seen this run, so 28 entries means a
  // 7-node path almost never repeats itself, and the second and third runs of
  // an evening still show new rooms.
  'slag_pool', 'the_tally_stone', 'quenching_trough', 'hollow_bellows',
  'ash_pilgrim', 'coin_in_the_coals', 'the_long_stair', 'ember_wardens_rest',
  'cracked_crucible', 'the_debtor', 'soot_market', 'last_delvers_pack',
  // v0.12.0 additions (appended at END; never reorder), themed with the
  // New Embers bestiary drop.
  'serpents_molt', 'the_snail_road', 'marshals_muster',
  // v0.22.0 additions (appended at deck END)
  'regents_causeway', 'the_kings_toll',
  // v0.25.0 additions (appended at deck END) — the Unquiet Deep, aftermath
  // of the Hearthless King.
  'the_toppled_crown', 'soot_choir', 'the_bridge_keeper',
  'cinder_hermit', 'glowworm_hollow', 'the_pale_lode',
  // v0.46.0 additions (appended at END; never reorder) — "The Delvers
  // Before": the delve remembers everyone who walked it ahead of you.
  'the_cold_camp', 'delvers_cairn', 'the_old_rope',
  'rivals_ledger', 'the_left_lantern', 'the_first_delver',
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
    ],
  ),
  'ember_shrine': EventDef(
    'ember_shrine',
    'Ember Shrine',
    'A shrine of warm stone. Offerings crumble to ash around it.',
    [
      OptionDef('Offer 20 gold (+18 embers)', {'gold': -20, 'embers': 18}),
      OptionDef('Pray quietly (heal 25%)', {'heal_pct': 25}),
      OptionDef('Move on', {}),
    ],
  ),
  'collapsed_tunnel': EventDef(
    'collapsed_tunnel',
    'Collapsed Tunnel',
    'The short way down is buried. You can dig, or squeeze the crack.',
    [
      OptionDef('Dig through (-6 hp, +30 gold)', {'hp': -6, 'gold': 30}),
      OptionDef('Squeeze past (safe)', {}),
    ],
  ),
  'wandering_peddler': EventDef(
    'wandering_peddler',
    'Wandering Peddler',
    'A hooded figure rattles a sack of oddities. "Cheap. Ish."',
    [
      OptionDef('Buy a mystery die (35 gold)', {
        'gold': -35,
        'gain_random_die': 3,
      }),
      OptionDef('Buy a trinket (60 gold)', {
        'gold': -60,
        'gain_random_relic': 1,
      }),
      OptionDef('Decline', {}),
    ],
  ),
  'dice_ghost': EventDef(
    'dice_ghost',
    'Dice Ghost',
    'A translucent gambler blocks the path. "One of yours... for one of mine."',
    [
      OptionDef('Trade (lose a random die, gain a random die)', {
        'lose_random_die': 1,
        'gain_random_die': 3,
      }),
      OptionDef('Refuse', {}),
    ],
  ),
  'molten_spring': EventDef(
    'molten_spring',
    'Molten Spring',
    'Water hisses over glowing rock. It smells of iron and heat.',
    [
      OptionDef('Bathe (heal 40%)', {'heal_pct': 40}),
      OptionDef('Temper yourself (-5 hp now, +4 max hp)', {
        'hp': -5,
        'max_hp': 4,
      }),
    ],
  ),
  'beggar_wisp': EventDef(
    'beggar_wisp',
    'Beggar Wisp',
    'A dim wisp flickers weakly, drawn to your coin pouch.',
    [
      OptionDef('Give 15 gold (+12 embers)', {'gold': -15, 'embers': 12}),
      OptionDef('Shoo it away', {}),
    ],
  ),
  'cracked_geode': EventDef(
    'cracked_geode',
    'Cracked Geode',
    'A geode the size of a barrel, split just enough to reach inside.',
    [
      OptionDef('Reach in (-4 hp, +40 gold)', {'hp': -4, 'gold': 40}),
      OptionDef('Chip at it safely (+15 gold)', {'gold': 15}),
    ],
  ),
  'old_delver': EventDef(
    'old_delver',
    'Old Delver',
    'A retired delver warms her hands. "Down there, steel beats luck."',
    [
      OptionDef('Trade stories (gain a d6 Forged Ember)', {
        'gain_die': 'd6_forged',
      }),
      OptionDef('Share supplies (-10 gold, heal 30%)', {
        'gold': -10,
        'heal_pct': 30,
      }),
      OptionDef('Nod and pass', {}),
    ],
  ),
  'ash_garden': EventDef(
    'ash_garden',
    'Ash Garden',
    'Grey flowers that bloom only underground. Beautiful. Poisonous.',
    [
      OptionDef('Pick a bloom (-3 hp, +14 embers)', {'hp': -3, 'embers': 14}),
      OptionDef('Admire and move on', {}),
    ],
  ),
  'tyrants_echo': EventDef(
    'tyrants_echo',
    "Tyrant's Echo",
    'The walls rumble with a voice from below: "TURN. BACK."',
    [
      OptionDef('Steel yourself (+3 max hp)', {'max_hp': 3}),
      OptionDef('Hurry past (safe)', {}),
    ],
  ),
  'gamblers_table': EventDef(
    'gamblers_table',
    "Gambler's Table",
    'Skeletal hands shuffle bone dice. A seat waits, dusted clean.',
    [
      OptionDef('Bet 25 gold (win a random relic)', {
        'gold': -25,
        'gain_random_relic': 1,
      }),
      OptionDef('Bet 10 gold (+22 gold back)', {'gold': -10, 'gold_after': 22}),
      OptionDef('Walk away', {}),
    ],
  ),
  'sealed_vault': EventDef(
    'sealed_vault',
    'Sealed Vault',
    'A vault door, warm to the touch. The lock is half melted.',
    [
      OptionDef('Force it (-8 hp, gain a random relic)', {
        'hp': -8,
        'gain_random_relic': 1,
      }),
      OptionDef('Leave it sealed', {}),
    ],
  ),
  'ember_moths': EventDef(
    'ember_moths',
    'Ember Moths',
    'A cloud of glowing moths settles on your pack, drawn to the embers.',
    [
      OptionDef('Let them feed (+8 embers)', {'embers': 8}),
      OptionDef('Wave them off', {}),
    ],
  ),
  'broken_cart': EventDef(
    'broken_cart',
    'Broken Cart',
    "A supply cart, wheel shattered. Its owner won't be back.",
    [
      OptionDef('Take supplies (heal 20%, +12 gold)', {
        'heal_pct': 20,
        'gold': 12,
      }),
      OptionDef('Leave it for someone else (+6 embers)', {'embers': 6}),
    ],
  ),
  'whispering_coals': EventDef(
    'whispering_coals',
    'Whispering Coals',
    'Coals spell out words when you stop looking directly at them.',
    [
      OptionDef('Listen (gain a random die of any tier)', {
        'gain_random_die': 3,
      }),
      OptionDef('Scatter the coals (+10 gold)', {'gold': 10}),
    ],
  ),
  // ---- v0.5.0 additions -------------------------------------------------
  // Design rule for every entry below: at least one option must cost
  // something real. A deck of free gifts is a deck of non-decisions, and it
  // also quietly inflates the run economy.
  'slag_pool': EventDef(
    'slag_pool',
    'Slag Pool',
    'Molten slag, skinned over with grey. Something glints under it.',
    [
      OptionDef('Reach in (-9 hp, gain a random die of any tier)', {
        'hp': -9,
        'gain_random_die': 3,
      }),
      OptionDef('Skim the surface (+14 gold)', {'gold': 14}),
      OptionDef('Move on', {}),
    ],
  ),
  'the_tally_stone': EventDef(
    'the_tally_stone',
    'The Tally Stone',
    'Scratches cover the stone. Every delver before you counted something.',
    [
      OptionDef('Add your mark (+12 embers)', {'embers': 12}),
      OptionDef('Read the marks instead (+18 gold)', {'gold': 18}),
    ],
  ),
  'quenching_trough': EventDef(
    'quenching_trough',
    'Quenching Trough',
    'Black water, still warm. Steel was cooled here, and often.',
    [
      OptionDef('Drink deep (heal 35%)', {'heal_pct': 35}),
      OptionDef('Temper a die in it (gain a Keen Ember)', {
        'gain_die': 'd6_keen',
      }),
      OptionDef('Leave it', {}),
    ],
  ),
  'hollow_bellows': EventDef(
    'hollow_bellows',
    'Hollow Bellows',
    'A great bellows, leather split. Air still moves through it, faintly.',
    [
      OptionDef('Breathe it in (+4 max hp)', {'max_hp': 4}),
      OptionDef('Strip the leather (+20 gold)', {'gold': 20}),
    ],
  ),
  'ash_pilgrim': EventDef(
    'ash_pilgrim',
    'Ash Pilgrim',
    'A figure kneels in the ash, facing further down. She does not look up.',
    [
      OptionDef('Give her 20 gold (gain a random relic)', {
        'gold': -20,
        'gain_random_relic': 1,
      }),
      OptionDef('Kneel beside her (+10 embers)', {'embers': 10}),
      OptionDef('Step around her', {}),
    ],
  ),
  'coin_in_the_coals': EventDef(
    'coin_in_the_coals',
    'Coin in the Coals',
    'A single coin sits in the embers, glowing. It has been there a while.',
    [
      OptionDef('Pick it out barehanded (-6 hp, +40 gold)', {
        'hp': -6,
        'gold': 40,
      }),
      OptionDef('Leave it burning', {}),
    ],
  ),
  'the_long_stair': EventDef(
    'the_long_stair',
    'The Long Stair',
    'Steps cut straight down, far past the light. A shortcut, or a drop.',
    [
      OptionDef('Take the stair (-10 hp, +16 embers)', {
        'hp': -10,
        'embers': 16,
      }),
      OptionDef('Take the slow way round (heal 15%)', {'heal_pct': 15}),
    ],
  ),
  'ember_wardens_rest': EventDef(
    'ember_wardens_rest',
    "Ember Warden's Rest",
    'An old warden sits against her shield, long past waking. Her kit is intact.',
    [
      OptionDef('Take her ward iron (gain a Ward Iron)', {
        'gain_die': 'd6_ward',
      }),
      OptionDef('Take her purse (+28 gold)', {'gold': 28}),
      OptionDef('Leave her as she is (+8 embers)', {'embers': 8}),
    ],
  ),
  'cracked_crucible': EventDef(
    'cracked_crucible',
    'Cracked Crucible',
    'A crucible split clean in half. Whatever it held got out.',
    [
      OptionDef('Melt a die down (lose a random die, +45 gold)', {
        'lose_random_die': 1,
        'gold': 45,
      }),
      OptionDef('Salvage the shards (+10 gold)', {'gold': 10}),
    ],
  ),
  'the_debtor': EventDef(
    'the_debtor',
    'The Debtor',
    'A man counts coins he does not have, over and over. He offers a wager.',
    [
      OptionDef('Stake 30 gold (+70 gold back)', {
        'gold': -30,
        'gold_after': 70,
      }),
      OptionDef('Stake 15 gold (+32 gold back)', {
        'gold': -15,
        'gold_after': 32,
      }),
      OptionDef('Refuse the wager', {}),
    ],
  ),
  'soot_market': EventDef(
    'soot_market',
    'Soot Market',
    'Three stalls, no traders. Prices are scratched into the ash beside each.',
    [
      OptionDef('Buy the sealed box (-25 gold, gain a random die)', {
        'gold': -25,
        'gain_random_die': 2,
      }),
      OptionDef('Buy the flask (-12 gold, heal 30%)', {
        'gold': -12,
        'heal_pct': 30,
      }),
      OptionDef('Buy nothing', {}),
    ],
  ),
  'last_delvers_pack': EventDef(
    'last_delvers_pack',
    "Last Delver's Pack",
    'A pack, neatly closed, set down deliberately. He meant to come back.',
    [
      OptionDef('Open it (gain a Stout Ember, -4 max hp from the weight)', {
        'gain_die': 'd6_stout',
        'max_hp': -4,
      }),
      OptionDef('Carry it out for him (+14 embers)', {'embers': 14}),
    ],
  ),

  // v0.12.0 additions -------------------------------------------------------
  'serpents_molt': EventDef(
    'serpents_molt',
    "Serpent's Molt",
    'A vent serpent\'s shed skin, still warm, coiled around something bright.',
    [
      OptionDef('Search the coils (-5 hp, +35 gold)', {'hp': -5, 'gold': 35}),
      OptionDef('Take a scale (+12 embers)', {'embers': 12}),
      OptionDef('Leave it be', {}),
    ],
  ),
  'the_snail_road': EventDef(
    'the_snail_road',
    'The Snail Road',
    'A trail of cooled slag, smooth as glass. The long way down — but level.',
    [
      OptionDef('Follow it (heal 20%)', {'heal_pct': 20}),
      OptionDef('Pry up a slag pearl (-3 hp, +20 gold)', {
        'hp': -3,
        'gold': 20,
      }),
    ],
  ),
  'marshals_muster': EventDef(
    'marshals_muster',
    "Marshal's Muster",
    'An old muster post. A rack of drill weapons stands unburnt, waiting.',
    [
      OptionDef('Drill until it hurts (-6 hp, +5 max hp)', {
        'hp': -6,
        'max_hp': 5,
      }),
      OptionDef('Take a drill die (-30 gold, gain a random die)', {
        'gold': -30,
        'gain_random_die': 2,
      }),
      OptionDef('Stand at ease', {}),
    ],
  ),

  // v0.22.0 additions -------------------------------------------------------
  'regents_causeway': EventDef(
    'regents_causeway',
    "Regent's Causeway",
    'A raised road of fused slag, swept clean. Someone still holds court below.',
    [
      OptionDef('Walk it openly (-4 hp, +30 gold in dropped tribute)', {
        'hp': -4,
        'gold': 30,
      }),
      OptionDef('Chip a paving stone (+13 embers)', {'embers': 13}),
      OptionDef('Go around', {}),
    ],
  ),
  'the_kings_toll': EventDef(
    'the_kings_toll',
    "The King's Toll",
    'A toll arch with no keeper. The bowl is stone-cold, but it is not empty.',
    [
      OptionDef('Pay the old way (-20 gold, heal 25%)', {
        'gold': -20,
        'heal_pct': 25,
      }),
      OptionDef('Take from the bowl (-6 hp, +26 gold)', {'hp': -6, 'gold': 26}),
      OptionDef('Pass without touching it', {}),
    ],
  ),

  // v0.25.0 additions -------------------------------------------------------
  'the_toppled_crown': EventDef(
    'the_toppled_crown',
    'The Toppled Crown',
    'A throne of slag lies on its side, crown still wedged beneath it. '
        'Nobody has dared to right it.',
    [
      OptionDef('Pry a jewel loose (-8 hp, +45 gold)', {'hp': -8, 'gold': 45}),
      OptionDef('Take the crown shard (gain a random die)', {
        'gain_random_die': 3,
      }),
      OptionDef('Bow and move on', {}),
    ],
  ),
  'soot_choir': EventDef(
    'soot_choir',
    'Soot Choir',
    'Wisps circle a dead chimney, humming in rounds. The tune knows you.',
    [
      OptionDef('Hum along (heal 20%)', {'heal_pct': 20}),
      OptionDef('Ask a blessing (-15 gold, +14 embers)', {
        'gold': -15,
        'embers': 14,
      }),
      OptionDef('Move on', {}),
    ],
  ),
  'the_bridge_keeper': EventDef(
    'the_bridge_keeper',
    'The Bridge Keeper',
    'A rope bridge over a char pit, and a keeper who remembers every '
        'crossing. Both look older than the deep.',
    [
      OptionDef('Pay 15 gold for the true path (+12 embers)', {
        'gold': -15,
        'embers': 12,
      }),
      OptionDef('Force the crossing (-7 hp, +25 gold)', {
        'hp': -7,
        'gold': 25,
      }),
      OptionDef('Turn back quietly', {}),
    ],
  ),
  'cinder_hermit': EventDef(
    'cinder_hermit',
    'Cinder Hermit',
    'He has lived down here since before the King fell. He trades in dice, '
        'and he is not lonely, thank you.',
    [
      OptionDef('Trade a die for his charm (lose a die, gain a relic)', {
        'lose_random_die': 1,
        'gain_random_relic': 1,
      }),
      OptionDef('Share your rations (-10 gold, heal 25%)', {
        'gold': -10,
        'heal_pct': 25,
      }),
      OptionDef('Leave him be', {}),
    ],
  ),
  'glowworm_hollow': EventDef(
    'glowworm_hollow',
    'Glowworm Hollow',
    'A ceiling of pale green stars. The light is cool, and it is the first '
        'thing down here that asks nothing of you.',
    [
      OptionDef('Bottle the glow (-20 gold, +4 max hp)', {
        'gold': -20,
        'max_hp': 4,
      }),
      OptionDef('Rest in the light (heal 30%)', {'heal_pct': 30}),
      OptionDef('Press on', {}),
    ],
  ),
  'the_pale_lode': EventDef(
    'the_pale_lode',
    'The Pale Lode',
    'A fresh crack in the wall shows a vein of bone-white ore. The King\'s '
        'fall shook loose more than thrones.',
    [
      OptionDef('Mine it (-6 hp, gain a random die)', {
        'hp': -6,
        'gain_random_die': 3,
      }),
      OptionDef('Chip a nugget (+20 gold)', {'gold': 20}),
      OptionDef('Mark it and move on (+5 embers)', {'embers': 5}),
    ],
  ),

  // v0.46.0 additions -------------------------------------------------------
  // "The Delvers Before" — cold camps, cairns, a rival's ledger, a lantern
  // left burning. Existing effect vocabulary only; no trade duplicates
  // (cinder_hermit owns die-for-relic, gamblers_table owns the wager,
  // last_delvers_pack owns the found pack).
  'the_cold_camp': EventDef(
    'the_cold_camp',
    'The Cold Camp',
    'A camp struck by no one: bedroll laid out, kettle on dead coals. '
        'Whoever slept here left in the middle of meaning to stay.',
    [
      OptionDef('Strip the camp (+18 gold)', {'gold': 18}),
      OptionDef('Use the bedroll (heal 25%)', {'heal_pct': 25}),
      OptionDef('Rekindle it (-8 gold, +10 embers)', {
        'gold': -8,
        'embers': 10,
      }),
    ],
  ),
  'delvers_cairn': EventDef(
    'delvers_cairn',
    "The Delver's Cairn",
    'Stones stacked hip-high, a die set on top like a name. The deep does '
        'not bury its own; someone stopped and did it anyway.',
    [
      OptionDef('Add a stone (-10 gold, +12 embers)', {
        'gold': -10,
        'embers': 12,
      }),
      OptionDef('Take the grave-die (-8 hp, random die)', {
        'hp': -8,
        'gain_random_die': 3,
      }),
      OptionDef('Pass in silence', {}),
    ],
  ),
  'the_old_rope': EventDef(
    'the_old_rope',
    'The Old Rope',
    'A knotted line runs down a shaft too dark to read. The anchor is '
        'rusted, the knots are good, and both facts are true at once.',
    [
      OptionDef('Climb down (-7 hp, +28 gold)', {
        'hp': -7,
        'gold': 28,
      }),
      OptionDef('Salvage the rope (+12 gold)', {'gold': 12}),
      OptionDef('Take the long way', {}),
    ],
  ),
  'rivals_ledger': EventDef(
    'rivals_ledger',
    "The Rival's Ledger",
    'A tally-book in a careful hand: routes, prices, warnings. The last '
        'entry stops mid-sentence, and you know her handwriting by now.',
    [
      OptionDef('Study her routes (-12 gold, +14 embers)', {
        'gold': -12,
        'embers': 14,
      }),
      OptionDef('Sell the maps (+22 gold)', {'gold': 22}),
      OptionDef('Burn it kindly (heal 15%)', {'heal_pct': 15}),
    ],
  ),
  'the_left_lantern': EventDef(
    'the_left_lantern',
    'The Left Lantern',
    'A lantern hangs at a fork, trimmed and burning. Nobody is here. '
        'Somebody meant there to be light anyway.',
    [
      OptionDef('Refill it (-20 gold, +4 max hp)', {
        'gold': -20,
        'max_hp': 4,
      }),
      OptionDef('Snuff it for the wick (+15 gold)', {'gold': 15}),
      OptionDef('Leave it burning (+8 embers)', {
        'embers': 8,
      }),
    ],
  ),
  'the_first_delver': EventDef(
    'the_first_delver',
    'The First Delver',
    'A mural older than the mine: one figure, one lantern, one road drawn '
        'down into the dark. The paint is soot. The soot is old.',
    [
      OptionDef('Study the mural (+8 embers)', {'embers': 8}),
      OptionDef('Sell a sketch of it (+20 gold)', {'gold': 20}),
      OptionDef('Restore it (-15 gold, +18 embers)', {
        'gold': -15,
        'embers': 18,
      }),
    ],
  ),
};

EventDef eventDef(String id) {
  final def = events[id];
  if (def == null) throw ArgumentError('unknown event id: $id');
  return def;
}
