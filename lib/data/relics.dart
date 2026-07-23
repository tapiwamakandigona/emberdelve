// data/relics.dart — Emberdelve relic roster (M3 content: 22 relics).
// CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m3-contract.md §7):
//   RelicDef { id, name, text, hooks }
// Hook vocabulary (exact — resolved by sim/combat.dart + sim/run_layer.dart,
// nothing else is legal). All hooks stack additively across owned relics:
//   max_hp=N          +N max hp (and current hp) on pickup — applied once
//   turn_block=N      +N block automatically at every combat turn start
//   attack_flat=N     +N to every attack assignment
//   block_flat=N      +N to every block assignment
//   min_roll=N        all dice rolls below N become N (after the die's own min)
//   on_max_gold=N     +N gold whenever a die shows its max face
//   thorns=N          enemy takes N damage after resolving an attack intent
//   heal_after_fight=N  heal N after every won encounter (capped at max hp)
//   gold_bonus=N      +N gold for every won fight
//   ember_bonus=N     +N embers for every won fight
//   elite_damage=N    +N to attack assignments vs elite/boss enemies
//   rest_bonus=N      rest heals +N
//   rerolls=N         N single-die rerolls per combat
//   shop_discount=N   N percent off shop prices (integer floor)
//
// `relicsOrder` lists every id in deterministic authoring order.

class RelicDef {
  final String id;
  final String name;
  final String text;
  final Map<String, int> hooks;
  const RelicDef(this.id, this.name, this.text, this.hooks);
}

const List<String> relicsOrder = [
  'ember_ring', 'kiln_key', 'ashen_idol', 'midas_die', 'lucky_coin',
  'iron_scale', 'bulwark_sigil', 'whetstone', 'war_drum', 'kite_charm',
  'loaded_pips', 'gamblers_eye', 'twin_eye', 'fire_salve', 'phoenix_feather',
  'thorn_band', 'slayers_mark', 'tyrant_bane', 'bedroll', 'haggler_tongue',
  'blood_ruby', 'ember_heartstone',
];

const Map<String, RelicDef> relics = {
  // economy ------------------------------------------------------------------
  'ember_ring': RelicDef('ember_ring', 'Ember Ring',
      '+5 gold from every won fight.', {'gold_bonus': 5}),
  'kiln_key': RelicDef('kiln_key', 'Kiln Key',
      '+8 gold from every won fight.', {'gold_bonus': 8}),
  'ashen_idol': RelicDef('ashen_idol', 'Ashen Idol',
      '+4 embers from every won fight.', {'ember_bonus': 4}),
  'midas_die': RelicDef('midas_die', 'Midas Die',
      '+3 gold whenever a die shows its highest face.', {'on_max_gold': 3}),
  'lucky_coin': RelicDef('lucky_coin', 'Lucky Coin',
      '+2 gold whenever a die shows its highest face.', {'on_max_gold': 2}),

  // combat — steady ------------------------------------------------------------
  'iron_scale': RelicDef('iron_scale', 'Iron Scale',
      'Gain 2 block at the start of every turn.', {'turn_block': 2}),
  'bulwark_sigil': RelicDef('bulwark_sigil', 'Bulwark Sigil',
      'Gain 3 block at the start of every turn.', {'turn_block': 3}),
  'whetstone': RelicDef('whetstone', 'Whetstone',
      'Attacks deal +1 damage.', {'attack_flat': 1}),
  'war_drum': RelicDef('war_drum', 'War Drum',
      'Attacks deal +2 damage.', {'attack_flat': 2}),
  'kite_charm': RelicDef('kite_charm', 'Kite Charm',
      'Blocks grant +1.', {'block_flat': 1}),
  'loaded_pips': RelicDef('loaded_pips', 'Loaded Pips',
      'Dice never roll below 2.', {'min_roll': 2}),

  // combat — tempo --------------------------------------------------------------
  'gamblers_eye': RelicDef('gamblers_eye', "Gambler's Eye",
      'Reroll one die once per fight.', {'rerolls': 1}),
  'twin_eye': RelicDef('twin_eye', 'Twin Eye',
      'Reroll a die twice per fight.', {'rerolls': 2}),
  'fire_salve': RelicDef('fire_salve', 'Fire Salve',
      'Heal 3 after every won fight.', {'heal_after_fight': 3}),
  'phoenix_feather': RelicDef('phoenix_feather', 'Phoenix Feather',
      'Heal 5 after every won fight.', {'heal_after_fight': 5}),
  'thorn_band': RelicDef('thorn_band', 'Thorn Band',
      'Attackers take 3 damage.', {'thorns': 3}),
  'slayers_mark': RelicDef('slayers_mark', "Slayer's Mark",
      '+3 attack damage vs elites and the boss.', {'elite_damage': 3}),
  'tyrant_bane': RelicDef('tyrant_bane', 'Tyrant Bane',
      '+5 attack damage vs elites and the boss.', {'elite_damage': 5}),

  // journey -----------------------------------------------------------------------
  'bedroll': RelicDef('bedroll', 'Bedroll',
      'Resting heals +4.', {'rest_bonus': 4}),
  'haggler_tongue': RelicDef('haggler_tongue', "Haggler's Tongue",
      'Shop prices 20% off.', {'shop_discount': 20}),
  'blood_ruby': RelicDef('blood_ruby', 'Blood Ruby',
      '+6 max HP.', {'max_hp': 6}),
  'ember_heartstone': RelicDef('ember_heartstone', 'Ember Heartstone',
      '+10 max HP.', {'max_hp': 10}),
};

RelicDef relicDef(String id) {
  final def = relics[id];
  if (def == null) throw ArgumentError('unknown relic id: $id');
  return def;
}
