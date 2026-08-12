// sim/keystones.dart — v7 keystones: run-long rules that reward a PATTERN of
// play rather than a specific die. Pure data + pure helpers: no Flutter, no
// dart:io, no unseeded randomness (contract §Sealed sim).
//
// Keystones are string IDs in `run['keystones']` (max three; v7 grants one).
// Their arithmetic lives in `resolveAssignment` (assignment-time keystones) or
// in `combatEndTurn` (living_bastion), never duplicated.

class KeystoneDef {
  final String id;
  final String name;
  final String blurb;
  const KeystoneDef(this.id, this.name, this.blurb);
}

/// Stable catalog order — offers are drawn against this order so the same
/// seed always produces the same three cards.
const List<String> keystonesOrder = <String>[
  'ashen_edge',
  'living_bastion',
  'crown_of_twelve',
  'twin_bellows',
];

const Map<String, KeystoneDef> keystones = <String, KeystoneDef>{
  'ashen_edge': KeystoneDef(
    'ashen_edge',
    'Ashen Edge',
    'Your first attack each turn gains +1 for every other die still unspent.',
  ),
  'living_bastion': KeystoneDef(
    'living_bastion',
    'Living Bastion',
    'Half your unused block carries into the next turn, up to 8.',
  ),
  'crown_of_twelve': KeystoneDef(
    'crown_of_twelve',
    'Crown of Twelve',
    'Each assignment gains +1 for every extra die SIZE used this turn.',
  ),
  'twin_bellows': KeystoneDef(
    'twin_bellows',
    'Twin Bellows',
    'Alternating attack and block pays +1, then +2, then +3. Repeat a verb '
        'and the chain resets.',
  ),
};

KeystoneDef keystoneDef(String id) =>
    keystones[id] ?? KeystoneDef(id, id, 'Unknown keystone.');

/// The single membership test. `run` is nullable so the pure resolver can be
/// called from previews that have no run (menus, tests).
bool hasKeystone(Map? run, String id) {
  final owned = (run?['keystones'] as List?)?.cast<String>();
  if (owned == null || owned.isEmpty) return false;
  return owned.contains(id);
}

/// Maximum keystones a single run may hold (contract §First four keystones).
const int keystoneCap = 3;
