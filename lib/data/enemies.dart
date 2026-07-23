// data/enemies.dart — Emberdelve enemy roster (M1). CONTENT AS DATA, ZERO LOGIC.
// SEALED SIM MODULE: pure Dart, no dart:io, no dart:math Random, no logic.
//
// 1:1 port of legacy/defold/data/enemies.lua — every id, name, hp and
// pattern amount/block copied EXACTLY (the ×2.75 balance numbers are
// sacred; docs/flutter-port-contract.md §4.5).
//
// Schema (docs/m1-contract.md §7):
//   { id: { 'id', 'name', 'hp', 'boss'(bool), 'elite'(bool),
//           'pattern': [ {'kind': 'attack'|'block'|'attack_block',
//                         'amount': N [, 'block': N]}, ... ] } }
// Intent = pattern entries cycled IN ORDER (index advances each enemy turn;
// deterministic, no RNG). Enemy block absorbs player damage the turn after
// it is gained and resets at enemy turn start.
//
// [enemiesOrder] is the Lua module's `_order`: every id in deterministic
// authoring order. Consumers iterate via [enemiesOrder], never map
// iteration order.
//
// Balance target: winnable but tense with pool {"d6","d6","d6"} (avg 10.5
// pips/turn) and 30 player hp. Regulars threaten ~4 dmg/turn, elites ~6,
// the boss ~7 with a block cycle that punishes all-in offense.

/// Lua `enemies._order` — deterministic authoring order, no duplicates.
const List<String> enemiesOrder = [
  'cinder_wisp', 'ash_rat', 'soot_shade', 'ember_beetle',
  'pyre_howler', 'kiln_golem',
  'ember_tyrant',
];

/// Lua `data/enemies.lua` table (minus `_order`, exposed as [enemiesOrder]).
const Map<String, Map<String, dynamic>> enemiesData = {
  // regulars ------------------------------------------------------------------
  'cinder_wisp': { // tutorial punchbag: pure attacks, teaches roll/assign
    'id': 'cinder_wisp', 'name': 'Cinder Wisp', 'hp': 12,
    'boss': false, 'elite': false,
    'pattern': [
      {'kind': 'attack', 'amount': 11},
      {'kind': 'attack', 'amount': 14},
      {'kind': 'attack', 'amount': 8},
    ],
  },
  'ash_rat': { // fast nibbler: low hp, relentless small hits, race it down
    'id': 'ash_rat', 'name': 'Ash Rat', 'hp': 10,
    'boss': false, 'elite': false,
    'pattern': [
      {'kind': 'attack', 'amount': 8},
      {'kind': 'attack', 'amount': 8},
      {'kind': 'attack_block', 'amount': 11, 'block': 8},
    ],
  },
  'soot_shade': { // teaches attack_block: guards while it claws
    'id': 'soot_shade', 'name': 'Soot Shade', 'hp': 13,
    'boss': false, 'elite': false,
    'pattern': [
      {'kind': 'attack_block', 'amount': 8, 'block': 8},
      {'kind': 'attack', 'amount': 14},
    ],
  },
  'ember_beetle': { // teaches enemy block: shells up, then bites hard
    'id': 'ember_beetle', 'name': 'Ember Beetle', 'hp': 15,
    'boss': false, 'elite': false,
    'pattern': [
      {'kind': 'block', 'amount': 14},
      {'kind': 'attack', 'amount': 16},
    ],
  },

  // elites --------------------------------------------------------------------
  'pyre_howler': { // elite bruiser: escalating hits, forces block discipline
    'id': 'pyre_howler', 'name': 'Pyre Howler', 'hp': 20,
    'boss': false, 'elite': true,
    'pattern': [
      {'kind': 'attack', 'amount': 16},
      {'kind': 'attack_block', 'amount': 14, 'block': 11},
      {'kind': 'attack', 'amount': 19},
    ],
  },
  'kiln_golem': { // elite wall: heavy guard cycle, punishes low damage pools
    'id': 'kiln_golem', 'name': 'Kiln Golem', 'hp': 24,
    'boss': false, 'elite': true,
    'pattern': [
      {'kind': 'block', 'amount': 16},
      {'kind': 'attack', 'amount': 19},
      {'kind': 'attack_block', 'amount': 14, 'block': 14},
    ],
  },

  // boss (exactly one) ----------------------------------------------------------
  'ember_tyrant': { // the run's finale: 4-beat cycle, big 9-hit telegraphed
    'id': 'ember_tyrant', 'name': 'Ember Tyrant', 'hp': 42,
    'boss': true, 'elite': false,
    'pattern': [
      {'kind': 'attack', 'amount': 16},
      {'kind': 'block', 'amount': 22},
      {'kind': 'attack_block', 'amount': 19, 'block': 14},
      {'kind': 'attack', 'amount': 25},
    ],
  },
};
