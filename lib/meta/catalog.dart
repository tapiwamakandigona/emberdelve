// meta/catalog.dart — shop content: weapons, skins, abilities (spec §4).
// Pure Dart data; integrity is unit-tested (unique ids, sane prices, exactly
// one free starter per category).

enum Currency { coins, feathers }

enum WeaponSpecial {
  none,
  wallBreaker, // cracked walls die in 1 hit
  burn, // damage-over-time on hit
  bonusHeart, // +1 max heart while equipped
  lunge, // attack dashes forward slightly
  tripleJump, // one extra air jump
}

class Weapon {
  final String id;
  final String name;
  final int damage;
  final double range; // px added to swing reach
  final int critPercent;
  final double critMultiplier;
  final WeaponSpecial special;
  final String specialText;
  final Currency currency;
  final int price; // 0 = starter
  const Weapon({
    required this.id,
    required this.name,
    required this.damage,
    required this.range,
    required this.critPercent,
    required this.critMultiplier,
    required this.special,
    required this.specialText,
    required this.currency,
    required this.price,
  });
}

class Skin {
  final String id;
  final String name;
  /// Melee power multiplier grows +0.03 per skin level (kills level it up).
  final double basePower;
  final Currency currency;
  final int price;
  const Skin({
    required this.id,
    required this.name,
    this.basePower = 1.0,
    required this.currency,
    required this.price,
  });

  /// Kills needed to reach [level] (gentle curve, capped by tests).
  static int killsForLevel(int level) => 25 * level * level;
  static const int maxLevel = 10;

  double powerAt(int level) =>
      basePower + 0.03 * (level - 1).clamp(0, maxLevel - 1);
}

// AKP-4d (owner-confirmed 2026-07-25): AK-style spell slot. One spell may
// be equipped; it grants a single cast per level run (the charge returns
// on the next run). All spells are premium — there is deliberately no free
// starter spell: it is a pure economy sink like AK's magic.
enum SpellEffect {
  emberBurst, // AoE fire ring around the player, ignites survivors
  stoneVeil, // several seconds of invulnerability
  hearthLight, // restore hearts
}

class Spell {
  final String id;
  final String name;
  final String text;
  final SpellEffect effect;
  final Currency currency;
  final int price;
  const Spell({
    required this.id,
    required this.name,
    required this.text,
    required this.effect,
    required this.currency,
    required this.price,
  });
}

class Ability {
  final String id;
  final String name;
  final String text;
  final Currency currency;
  final int price;
  const Ability({
    required this.id,
    required this.name,
    required this.text,
    required this.currency,
    required this.price,
  });
}

const List<Weapon> kWeapons = [
  Weapon(
    id: 'squire_blade',
    name: "Squire's Blade",
    damage: 3,
    range: 18,
    critPercent: 5,
    critMultiplier: 1.5,
    special: WeaponSpecial.none,
    specialText: 'A trusty first sword.',
    currency: Currency.coins,
    price: 0,
  ),
  Weapon(
    id: 'woodsman_axe',
    name: "Woodsman's Axe",
    damage: 5,
    range: 16,
    critPercent: 10,
    critMultiplier: 1.6,
    special: WeaponSpecial.wallBreaker,
    specialText: 'Breaks cracked walls in one chop.',
    currency: Currency.coins,
    price: 450,
  ),
  Weapon(
    id: 'ember_fang',
    name: 'Ember Fang',
    damage: 4,
    range: 18,
    critPercent: 15,
    critMultiplier: 1.7,
    special: WeaponSpecial.burn,
    specialText: 'Ignites foes: 1 damage/s for 3s.',
    currency: Currency.coins,
    price: 900,
  ),
  Weapon(
    id: 'warden_blade',
    name: 'Warden Blade',
    damage: 5,
    range: 20,
    critPercent: 8,
    critMultiplier: 1.6,
    special: WeaponSpecial.bonusHeart,
    specialText: '+1 max heart while equipped.',
    currency: Currency.coins,
    price: 1500,
  ),
  Weapon(
    id: 'skypiercer',
    name: 'Skypiercer',
    damage: 6,
    range: 24,
    critPercent: 12,
    critMultiplier: 1.8,
    special: WeaponSpecial.lunge,
    specialText: 'Swings lunge you forward.',
    currency: Currency.feathers,
    price: 12,
  ),
  Weapon(
    id: 'wind_gods_hammer',
    name: "Wind God's Hammer",
    damage: 9,
    range: 14,
    critPercent: 21,
    critMultiplier: 2.0,
    special: WeaponSpecial.tripleJump,
    specialText: 'Allows triple-jumping (an extra jump while airborne).',
    currency: Currency.feathers,
    price: 20,
  ),
];

const List<Skin> kSkins = [
  Skin(id: 'red', name: 'Red', currency: Currency.coins, price: 0),
  Skin(id: 'ember_monk', name: 'Ember Monk', currency: Currency.coins, price: 800),
  Skin(id: 'shadow_thief', name: 'Shadow Thief', currency: Currency.coins, price: 1200),
  Skin(id: 'hearth_knight', name: 'Hearth Knight', currency: Currency.feathers, price: 15),
  // Stage 2 (owner-directed 2026-07-25): two more characters.
  Skin(id: 'grove_sentinel', name: 'Grove Sentinel', currency: Currency.coins, price: 1600),
  Skin(id: 'ash_wraith', name: 'Ash Wraith', currency: Currency.feathers, price: 25),
];

const List<Ability> kAbilities = [
  Ability(
    id: 'coin_magnet',
    name: 'Coin Magnet',
    text: 'Coins drift to you from farther away.',
    currency: Currency.coins,
    price: 600,
  ),
  Ability(
    id: 'apple_pouch',
    name: 'Apple Pouch',
    text: 'Carry +3 apples.',
    currency: Currency.coins,
    price: 500,
  ),
  Ability(
    id: 'haggler',
    name: 'Haggler',
    text: 'Coin prices in the shop are 10% lower.',
    currency: Currency.coins,
    price: 1000,
  ),
  Ability(
    id: 'chest_radar',
    name: 'Chest Radar',
    text: 'Pings when a chest is near.',
    currency: Currency.feathers,
    price: 8,
  ),
];

const List<Spell> kSpells = [
  Spell(
    id: 'ember_burst',
    name: 'Ember Burst',
    text: 'A ring of flame erupts around you, scorching and igniting '
        'nearby foes. Once per level.',
    effect: SpellEffect.emberBurst,
    currency: Currency.coins,
    price: 700,
  ),
  Spell(
    id: 'stone_veil',
    name: 'Stone Veil',
    text: 'Harden like kiln-fired clay: 3 seconds of immunity. '
        'Once per level.',
    effect: SpellEffect.stoneVeil,
    currency: Currency.coins,
    price: 1100,
  ),
  Spell(
    id: 'hearth_light',
    name: 'Hearth Light',
    text: 'A warm glow restores two hearts. Once per level.',
    effect: SpellEffect.hearthLight,
    currency: Currency.feathers,
    price: 10,
  ),
];

Weapon weaponById(String id) => kWeapons.firstWhere((w) => w.id == id);
Skin skinById(String id) => kSkins.firstWhere((s) => s.id == id);
Ability abilityById(String id) => kAbilities.firstWhere((a) => a.id == id);
Spell spellById(String id) => kSpells.firstWhere((s) => s.id == id);
