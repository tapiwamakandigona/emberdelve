// meta/progress_state.dart — world/level registry + unlock rules.
// Pure Dart, unit-tested.

import '../core/save.dart';
import 'catalog.dart';

class LevelEntry {
  final String id; // matches assets/levels/<id>.txt
  final String title;
  final bool isBoss;
  const LevelEntry(this.id, this.title, {this.isBoss = false});
}

/// World 1 — Emberwood. Order matters: each level unlocks the next;
/// the boss needs every prior level finished.
const List<LevelEntry> kWorld1 = [
  LevelEntry('w1_l1', 'Forest Edge'),
  LevelEntry('w1_l2', 'Old Orchard'),
  LevelEntry('w1_l3', 'Bramble Hollow'),
  LevelEntry('w1_l4', 'Charcoal Camp'),
  LevelEntry('w1_l5', 'Rootway Ruins'),
  LevelEntry('w1_boss', 'Grove Golem', isBoss: true),
];

bool isLevelUnlocked(SaveData save, int index, {List<LevelEntry>? world}) {
  final w = world ?? kWorld1;
  if (index <= 0) return true;
  if (index >= w.length) return false;
  final entry = w[index];
  if (entry.isBoss) {
    return w
        .take(index)
        .every((e) => save.levels[e.id]?.finished ?? false);
  }
  return save.levels[w[index - 1].id]?.finished ?? false;
}

int totalMedals(SaveData save, {List<LevelEntry>? world}) =>
    (world ?? kWorld1)
        .map((e) => save.levels[e.id]?.medals ?? 0)
        .fold(0, (a, b) => a + b);

/// Skin level from lifetime kills while wearing it (see Skin.killsForLevel).
int skinLevel(SaveData save, String skinId) {
  final kills = save.skinKills[skinId] ?? 0;
  var level = 1;
  while (level < Skin.maxLevel && kills >= Skin.killsForLevel(level)) {
    level++;
  }
  return level;
}

/// Effective melee damage multiplier: skin power x weapon-agnostic bonuses.
double meleePower(SaveData save) =>
    skinById(save.equippedSkin).powerAt(skinLevel(save, save.equippedSkin));

int maxHearts(SaveData save) {
  var hearts = 3;
  if (weaponById(save.equippedWeapon).special == WeaponSpecial.bonusHeart) {
    hearts += 1;
  }
  return hearts;
}

int appleCapacity(SaveData save) =>
    10 + (save.ownedAbilities.contains('apple_pouch') ? 3 : 0);
