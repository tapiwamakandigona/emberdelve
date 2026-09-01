// data/characters.dart — Playable delvers (M3). CONTENT AS DATA, ZERO LOGIC.
//
// Schema:
//   CharacterDef { id, name, text, maxHp, startDice:[id...], startRelic:<id|null>,
//                  unlockEmbers }
// The first character is free; others unlock via the meta layer (embers).
// start_run injects a character id; run_layer applies maxHp/startDice/startRelic
// deterministically before map entry. Unknown/locked selection at the sim layer
// is treated as the default (the meta layer enforces unlock gating, not the sim).
//
// `charactersOrder` = deterministic authoring order.

class CharacterDef {
  final String id;
  final String name;
  final String text;
  final int maxHp;
  final List<String> startDice;
  final String? startRelic;
  final int unlockEmbers;

  /// v0.135.0 The Runesmith: marks worked before the first floor. Each
  /// entry is {die: 1-based index into startDice, face: natural face,
  /// rune: faceRunes id}, applied deterministically by run_layer at
  /// start_run. These are the SMITH'S marks, not the player's — they do
  /// not count toward tempers_used, runes_tempered, or the temper cap.
  final List<Map<String, Object>> startTempers;
  const CharacterDef(
    this.id,
    this.name,
    this.text, {
    required this.maxHp,
    required this.startDice,
    this.startRelic,
    this.unlockEmbers = 0,
    this.startTempers = const [],
  });
}

const String defaultCharacter = 'kindler';

const List<String> charactersOrder = [
  'kindler',
  'warden',
  'gambler',
  'ascetic',
  'peddler',
  'tinker',
  // v0.118.0 — append-LAST, same discipline as every roster bit.
  'flintwright',
  // v0.135.0 — append-LAST.
  'runesmith',
  // v0.145.0 — append-LAST.
  'bearer',
  'mender',
  // v0.158.0 — append-LAST.
  'shieldwright',
  // v0.162.0 — append-LAST.
  'gilder',
  // v0.168.0 — append-LAST.
  'cutler',
  // v0.171.0 — append-LAST.
  'collier',
  // v0.175.0 — append-LAST.
  'stoker',
  // sixteenth delver — append-LAST. Delve-code bits 31..34 are now FULL:
  // the roster is complete at sixteen chairs. No seventeenth.
  'hearthkeeper',
  // ── THE SECOND CIRCLE ────────────────────────────────────────────
  // DEMAND 2026-09-01f: the first real player review asked for more
  // delvers. The first fire's sixteen chairs stay complete exactly as
  // published; newcomers sit at a SECOND circle. Delve codes carry
  // index 16+ in the v2 ten-char form (delve_code.dart) — every code
  // ever shared stays byte-identical. Append-LAST discipline unchanged.
  'hedger',
  // v0.180.0 — append-LAST.
  'miller',
  'brewster',
  'lamplighter',
  'farrier',
  'glover',
];

const Map<String, CharacterDef> characters = {
  'kindler': CharacterDef(
    'kindler',
    'The Kindler',
    'The balanced start: three plain Ember Dice, 30 HP.',
    maxHp: 30,
    startDice: ['d6', 'd6', 'd6'],
    unlockEmbers: 0,
  ),
  'warden': CharacterDef(
    'warden',
    'The Warden',
    'Tanky. Extra HP, an Iron Scale, and a Slate Chip guard die.',
    maxHp: 32,
    startDice: ['d6', 'd6', 'd4_guard'],
    startRelic: 'iron_scale',
    unlockEmbers: 120,
  ),
  'gambler': CharacterDef(
    'gambler',
    'The Gambler',
    'High variance. A d4 luck die and a reroll trinket.',
    maxHp: 27,
    startDice: ['d6', 'd6', 'd4_lucky'],
    startRelic: 'gamblers_eye',
    unlockEmbers: 200,
  ),
  'ascetic': CharacterDef(
    'ascetic',
    'The Ascetic',
    'Fragile but sharp: a Brand Iron and a Whetstone, low HP.',
    maxHp: 26,
    startDice: ['d6', 'd6', 'd6_brand'],
    startRelic: 'whetstone',
    unlockEmbers: 320,
  ),
  // v0.40.0 The Peddler: the economy archetype the roster lacked. A weaker
  // pouch than the Kindler (14 pips vs 18), traded for a Kiln Key — every won
  // fight pays +8 gold, so the shops do the delver's forging. Appended
  // LAST so charactersOrder indexes (delve-code bits 31..34, v0.37.0) stay
  // stable for every code already shared.
  'peddler': CharacterDef(
    'peddler',
    'The Peddler',
    'Mercantile. Lean dice and a Kiln Key — every won fight pays well.',
    maxHp: 31,
    startDice: ['d6', 'd6', 'd4'],
    startRelic: 'kiln_key',
    unlockEmbers: 450,
  ),
  // v0.50.0 The Tinker: the control archetype — the roster's variance runs
  // from the Gambler (widest) to nothing at the narrow end until now. A
  // Steady Ember (min 3) under Loaded Pips (min 2 on everything) gives the
  // best floors in the roster, traded for the smallest pip ceiling (16 vs
  // the Kindler's 18). 400-seed sweep: 85.25/58.25/31.0 — in band, normal
  // level with the other skill delvers. Reuses an existing relic on purpose: adding a NEW relic
  // resizes the shop offer pool and re-anchors every golden. Appended LAST
  // so charactersOrder indexes (delve-code bits 31..34) stay stable.
  'tinker': CharacterDef(
    'tinker',
    'The Tinker',
    'Consistent. Steady dice under Loaded Pips — never a dead roll.',
    maxHp: 30,
    startDice: ['d6_steady', 'd6', 'd4'],
    startRelic: 'loaded_pips',
    unlockEmbers: 600,
  ),
  // v0.118.0 The Flintwright: the SWARM archetype — the only delver who
  // starts with FOUR dice, and none of them grand. More rolls, smaller
  // promises, twice the forge futures. Pure data (existing dice only), so
  // seeded runs for every other delver are untouched — no re-anchor.
  // Balance swept before shipping; hp is the tuning knob (see release notes).
  'flintwright': CharacterDef(
    'flintwright',
    'The Flintwright',
    'The swarm: FOUR small dice, 24 HP — shards and chips, nothing grand.',
    maxHp: 24,
    startDice: ['d4', 'd4', 'd4_spark', 'd4_guard'],
    unlockEmbers: 750,
  ),
  // v0.135.0 The Runesmith — the eighth delver, the temper specialist:
  // arrives with one mark already worked (surge on the d8's own top face).
  // HP is the balance knob (sweeps in docs/improvements/v0.135.0): the
  // free mark is real tempo, so the runesmith runs lean.
  'runesmith': CharacterDef(
    'runesmith',
    'The Runesmith',
    'Arrives marked: a Deep Coal with Surge already worked into its 8. '
        'Lean, and the anvil answers them first.',
    maxHp: 26,
    startDice: ['d6', 'd6', 'd8'],
    startTempers: [
      {'die': 3, 'face': 8, 'rune': 'surge'},
    ],
    unlockEmbers: 900,
  ),
  // v0.145.0 The Bearer — the ninth delver, the GIANT: the flintwright's
  // exact opposite pole. TWO dice only, one of them the biggest starting
  // die in any kit (a d10 on floor one). Fewest rolls, grandest promises,
  // and every temper mark lands on half the pouch. Pure data (existing
  // dice only) — no re-anchor. HP is the tuning knob (sweeps in
  // docs/improvements/v0.145.0).
  'bearer': CharacterDef(
    'bearer',
    'The Bearer',
    'The giant: TWO dice, one a Molten Core — few rolls, grand promises.',
    maxHp: 36,
    startDice: ['d12', 'd8'],
    startRelic: 'iron_scale',
    startTempers: [
      {'die': 1, 'face': 12, 'rune': 'echo'},
    ],
    unlockEmbers: 1050,
  ),
  // v0.150.0 The Mender — the tenth delver, the HEALER: the mend rune
  // arrives worked into the Deep Coal's WORST face, so the bad roll is
  // the one that stitches. Pure data (existing dice + rune) — no
  // re-anchor. HP is the tuning knob (sweeps in docs/improvements).
  'mender': CharacterDef(
    'mender',
    'The Mender',
    'The healer: a Deep Coal whose 1 stitches a wound — the worst roll pays.',
    maxHp: 24,
    startDice: ['d8', 'd6', 'd6'],
    startTempers: [
      {'die': 1, 'face': 1, 'rune': 'mend'},
    ],
    unlockEmbers: 1200,
  ),
  // v0.158.0 The Shieldwright — the eleventh delver, the WARD: the first
  // kit to lead with a DEEP mark (v0.155.0). Aegis II is already worked
  // into an Ember Die's 6 — the shield forged before the first floor.
  // Pure data (existing dice + rune tiers) — no re-anchor. HP is the
  // tuning knob (sweeps in docs/improvements/v0.158.0).
  'shieldwright': CharacterDef(
    'shieldwright',
    'The Shieldwright',
    'The ward: an Ember Die whose 6 carries a DEEP Aegis — '
        'the shield was forged before the delve.',
    maxHp: 26,
    startDice: ['d6', 'd6', 'd6'],
    startTempers: [
      {'die': 1, 'face': 6, 'rune': 'aegis', 'tier': 2},
    ],
    unlockEmbers: 1350,
  ),
  // v0.162.0 The Gilder — the twelfth delver, the GOLDSMITH: the first
  // kit with TWO smith's marks. Gilt is worked into both Ember Dice
  // sixes, so the pouch itself pays — coin on the roll, not on the kill
  // (the peddler's opposite pole: kiln gold arrives per fight won, gilt
  // gold per gilded face spent). Pure data (existing dice + rune) — no
  // re-anchor. HP is the tuning knob (sweeps in docs/improvements).
  'gilder': CharacterDef(
    'gilder',
    'The Gilder',
    'The goldsmith: TWO gilt marks — both Ember Dice sixes pay coin '
        'when they land.',
    maxHp: 28,
    startDice: ['d6', 'd6', 'd6'],
    startTempers: [
      {'die': 1, 'face': 6, 'rune': 'gilt'},
      {'die': 2, 'face': 6, 'rune': 'gilt'},
    ],
    unlockEmbers: 1500,
  ),
  // v0.168.0 The Cutler — the thirteenth delver, the KNIFE-MAKER: the
  // first kit with two DIFFERENT marks. Edge and spine — a Blade rides
  // the Deep Coal's 8 and an Aegis rides an Ember Die's 6, so the kit
  // opens with both a sharpened promise and a guarded one. Pure data
  // (existing dice + runes) — no re-anchor. HP is the tuning knob
  // (sweeps in docs/improvements/v0.168.0).
  'cutler': CharacterDef(
    'cutler',
    'The Cutler',
    'The knife-maker: edge and spine \u2014 a Blade on the Deep '
        'Coal\u2019s 8, an Aegis on an Ember Die\u2019s 6.',
    maxHp: 24,
    startDice: ['d6', 'd6', 'd8'],
    startTempers: [
      {'die': 3, 'face': 8, 'rune': 'blade'},
      {'die': 1, 'face': 6, 'rune': 'aegis'},
    ],
    unlockEmbers: 1650,
  ),
  // v0.171.0 The Collier: the charcoal-burner — the first delver whose
  // WHOLE pool arrives worked. Three Ember Dice, three tier-1 marks from
  // the smith: a Blade and a Gilt on two of the sixes, a Mend banked on a
  // low face (the mender's clever coal: the one that keeps the burn
  // alive). No relic. Every prior marked kit left plain dice in the pool;
  // the full-worked pool is the open novelty slot.
  'collier': CharacterDef(
    'collier',
    'The Collier',
    'The charcoal-burner: every die worked \u2014 a Blade and a Gilt '
        'on the sixes, a Mend on the low coal.',
    maxHp: 27,
    startDice: ['d6', 'd6', 'd6'],
    startTempers: [
      {'die': 1, 'face': 6, 'rune': 'blade'},
      {'die': 2, 'face': 6, 'rune': 'gilt'},
      {'die': 3, 'face': 1, 'rune': 'mend'},
    ],
    unlockEmbers: 1800,
  ),
  // v0.175.0 The Stoker: the furnace-feeder — the first all-heavy pouch.
  // Three plain d8s: big coals, thrown whole. No relic, no smith's marks;
  // the identity is the weight of the dice themselves. Every prior pouch
  // mixed sizes or stayed at sixes (the flintwright went the OTHER way,
  // four small); the uniform heavy pool is the open novelty slot.
  'stoker': CharacterDef(
    'stoker',
    'The Stoker',
    'The furnace-feeder: three heavy Ember Dice \u2014 big coals, '
        'thrown whole.',
    maxHp: 16,
    startDice: ['d8', 'd8', 'd8'],
    unlockEmbers: 1950,
  ),
  // The Hearthkeeper: the SIXTEENTH and FINAL chair — the sworn pouch.
  // Every die is a forged specialist and none of them plain: a Brand Iron
  // that only strikes, a Ward Iron that only shields, a Steady Ember that
  // never rolls under 3. The collier's pouch was worked BY the smith
  // (plain dice, rune faces); the hearthkeeper's dice were BORN to their
  // work (forged die types, committed roles). Two of three dice locked to
  // a single job is the tension the sweep prices in; HP is the tuning
  // knob (sweeps in docs/improvements). Pure data — existing die ids,
  // no relic, no marks, no re-anchor. The delve-code delver index
  // (bits 31..34) holds sixteen; this delver takes the last value.
  'hearthkeeper': CharacterDef(
    'hearthkeeper',
    'The Hearthkeeper',
    'The last chair: every die sworn \u2014 a Brand that only strikes, '
        'a Ward that only shields, a Steady that never fails.',
    maxHp: 26,
    startDice: ['d6_brand', 'd6_ward', 'd6_steady'],
    unlockEmbers: 2100,
  ),
  // v0.179.0 The Hedger: the SEVENTEENTH delver — first chair of the
  // second circle, and the roster's first retaliation identity. The
  // kindler's own pouch under a Thorn Band: same three plain Ember
  // Dice, but a landed blow answers for 3 — an unblocked hit is no
  // longer pure loss, which inverts the block calculus the other
  // sixteen play by. Pure data (existing relic, existing dice, no
  // marks); HP 20 from the v0.179.0 sweep (400 seeds: easy 89.25 /
  // normal 65.50 / hard 43.00 — all bands): the hedge is sharp, not
  // thick.
  'hedger': CharacterDef(
    'hedger',
    'The Hedger',
    'The thorn-layer: a Thorn Band and plain Ember Dice \u2014 '
        'every blow against them is answered.',
    maxHp: 20,
    startDice: ['d6', 'd6', 'd6'],
    startRelic: 'thorn_band',
    unlockEmbers: 2250,
  ),
  // v0.180.0 The Miller: the second chair of the second circle — the
  // millstone and the grist. One Molten Core and two Flint Shards: the
  // roster's extremes in ONE pouch (the bearer went all-grand, the
  // flintwright all-small; nobody straddled). No relic, no marks — the
  // spread of the dice IS the identity: one grinding roll that promises
  // everything, two chips that keep the smaller promises while it turns.
  // HP is the tuning knob (sweep in docs/improvements).
  'miller': CharacterDef(
    'miller',
    'The Miller',
    'The millstone and the grist: one grand die, two small \u2014 '
        'the grind and what it feeds.',
    maxHp: 27,
    startDice: ['d12', 'd4', 'd4'],
    unlockEmbers: 2400,
  ),
  // v0.181.0 The Brewster: the third chair of the second circle — the
  // rest-economy identity the gap analysis flagged. A staircase pouch
  // (d8/d6/d4, the only strictly-descending set) and a Hearth Kettle:
  // thin in the fight, but every rest pays back double. The delve is
  // walked kettle to kettle. HP is the tuning knob (sweep in
  // docs/improvements).
  'brewster': CharacterDef(
    'brewster',
    'The Brewster',
    'The kettle-keeper: thin dice and a Hearth Kettle \u2014 the delve '
        'is walked rest to rest.',
    maxHp: 25,
    startDice: ['d8', 'd6', 'd4'],
    startRelic: 'hearth_kettle',
    unlockEmbers: 2550,
  ),
  // v0.182.0 The Lamplighter: the fourth chair of the second circle — the
  // JACKPOT identity, from the second gap pass. Three Glowing Embers
  // (d6_ember, +2 whenever the max face lands) and nothing else: a pouch
  // of ordinary sixes that flare. The gambler fishes with a lucky d4;
  // the lamplighter carries a whole kit that spikes. Pure data (existing
  // specialty die, runesmith precedent for an all-specialty pouch). HP
  // is the tuning knob (sweep in docs/improvements).
  'lamplighter': CharacterDef(
    'lamplighter',
    'The Lamplighter',
    'The lamp-tender: three Glowing Embers \u2014 ordinary sixes that '
        'flare when they land true.',
    maxHp: 24,
    startDice: ['d6_ember', 'd6_ember', 'd6_ember'],
    unlockEmbers: 2700,
  ),
  // v0.183.0 The Farrier: the fifth chair of the second circle — the
  // STEADY counterpart to the lamplighter's spike, from the same gap
  // pass. Three Forged Embers (d6_forged, flat +1 attack and +1 block on
  // every roll — never started by any kit): no flare, no fishing, just
  // iron that is always a little more than the face says. Pure data
  // (existing specialty die). HP is the tuning knob (sweep in
  // docs/improvements).
  'farrier': CharacterDef(
    'farrier',
    'The Farrier',
    'The iron-shoer: three Forged Embers \u2014 every roll a little '
        'more than its face, no roll ever less.',
    maxHp: 12,
    startDice: ['d6_forged', 'd6_forged', 'd6_forged'],
    unlockEmbers: 2850,
  ),
  // v0.184.0 The Glover: the sixth chair of the second circle — the
  // SPLIT-HANDS identity, and the kit that finally starts the last two
  // unused tier-1 specialties. One Keen Ember (attack-only +1), one
  // Stout Ember (block-only +1), one bare Ember Die: the right hand
  // cuts, the left hand holds, the bare hand learns. Pure data. HP is
  // the tuning knob (sweep in docs/improvements).
  'glover': CharacterDef(
    'glover',
    'The Glover',
    'The split-handed: a keen right glove, a stout left glove, and '
        'one bare hand still learning.',
    maxHp: 23,
    startDice: ['d6_keen', 'd6_stout', 'd6'],
    unlockEmbers: 3000,
  ),
};

CharacterDef characterDef(String? id) =>
    characters[id] ?? characters[defaultCharacter]!;
