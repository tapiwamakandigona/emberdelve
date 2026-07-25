// game/core_loadout.dart — snapshot of the player's equipped meta for a level
// run. Pure Dart; built from SaveData via [Loadout.fromSave] so the session
// never touches save/UI state mid-run.

import '../core/save.dart';
import '../meta/catalog.dart';
import '../meta/progress_state.dart' as progress;

class Loadout {
  final Weapon weapon;
  final int maxHearts;
  final double meleePower;
  final int extraAirJumps;
  final int appleCapacity;
  final bool coinMagnet;
  final String skinId;
  final Spell? spell; // AKP-4d: equipped spell, one cast per run (null = none)

  const Loadout({
    required this.weapon,
    required this.maxHearts,
    required this.meleePower,
    required this.extraAirJumps,
    required this.appleCapacity,
    required this.coinMagnet,
    required this.skinId,
    this.spell,
  });

  bool get wallBreaker => weapon.special == WeaponSpecial.wallBreaker;
  bool get burnOnHit => weapon.special == WeaponSpecial.burn;

  factory Loadout.fromSave(SaveData save) {
    final weapon = weaponById(save.equippedWeapon);
    return Loadout(
      weapon: weapon,
      maxHearts: progress.maxHearts(save),
      meleePower: progress.meleePower(save),
      extraAirJumps: weapon.special == WeaponSpecial.tripleJump ? 1 : 0,
      appleCapacity: progress.appleCapacity(save),
      coinMagnet: save.ownedAbilities.contains('coin_magnet'),
      skinId: save.equippedSkin,
      spell: save.equippedSpell.isNotEmpty &&
              save.ownedSpells.contains(save.equippedSpell)
          ? spellById(save.equippedSpell)
          : null,
    );
  }

  /// Bare starter loadout for tests.
  factory Loadout.starter({Weapon? weapon}) => Loadout(
        weapon: weapon ?? weaponById('squire_blade'),
        maxHearts: 3,
        meleePower: 1.0,
        extraAirJumps: 0,
        appleCapacity: 10,
        coinMagnet: false,
        skinId: 'red',
      );
}
