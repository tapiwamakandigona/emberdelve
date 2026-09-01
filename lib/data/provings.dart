// lib/data/provings.dart — The Provings (v0.38.0): eight named, curated
// challenge delves. Each is an exact run — seed, delver, difficulty,
// ascension — so every player who takes a proving walks the same floors.
// Every seed here was machine-proven winnable by the autoplay bot
// (tool/trial_seed_hunt.dart), and the bot plays worse than a person, so
// "winnable" is a fact, not a hope.
//
// Charter (§Ethics): clearing a proving pays nothing and unlocks nothing —
// the clear mark is the whole prize, same stance as the Ledger. No order is
// forced, nothing rotates, nothing expires. The two hard provings require
// hard mode exactly as any hard run does; the list states that plainly and
// never prompts a purchase.

class ProvingDef {
  final String id;
  final String title;

  /// One factual line about what makes this delve its own kind of test.
  final String blurb;

  final int seed;
  final String character; // characters.dart id
  final String difficulty; // easy | normal | hard
  final int ascension;

  /// v0.108.0 The Proven Rules: declared run modifiers (mutators.dart ids),
  /// stated plainly on the card. A modded proving shows no Delve Code — a
  /// code cannot carry rules (delve_code.dart), and a code that reproduced
  /// an unmodded run would be a lie.
  final List<String> mutators;

  const ProvingDef({
    required this.id,
    required this.title,
    required this.blurb,
    required this.seed,
    required this.character,
    required this.difficulty,
    this.ascension = 0,
    this.mutators = const [],
  });
}

/// Display order — roughly easiest first, but nothing is gated on order.
const List<ProvingDef> provings = [
  ProvingDef(
    id: 'first_flame',
    title: 'The First Flame',
    blurb: 'The Kindler on gentle floors. Where every delver starts.',
    seed: 1,
    character: 'kindler',
    difficulty: 'easy',
  ),
  ProvingDef(
    id: 'shield_oath',
    title: 'The Shield Oath',
    blurb: 'The Warden holds the line. Block bought here pays later.',
    seed: 7,
    character: 'warden',
    difficulty: 'easy',
  ),
  ProvingDef(
    id: 'loaded_dice',
    title: 'The Loaded Dice',
    blurb: 'The Gambler at even odds. Rerolls are a currency — spend them.',
    seed: 11,
    character: 'gambler',
    difficulty: 'normal',
  ),
  ProvingDef(
    id: 'empty_hand',
    title: 'The Empty Hand',
    blurb: 'The Ascetic, who carries less and needs less.',
    seed: 6,
    character: 'ascetic',
    difficulty: 'normal',
  ),
  // v0.41.0: the ninth proving, so every delver has a seat at the table.
  // Seed 2 is bot-win proven for the peddler on normal (see the winnability
  // test) — the gold engine has to carry a lean pouch the whole way down.
  ProvingDef(
    id: 'full_purse',
    title: 'The Full Purse',
    blurb: 'The Peddler on normal floors. Lean dice; the Kiln Key pays.',
    seed: 2,
    character: 'peddler',
    difficulty: 'normal',
  ),
  // v0.52.0: the tenth proving — the last empty seat. Seed 131 is bot-win
  // proven for the tinker on normal (tool/tinker_proving_hunt_test.dart);
  // steady dice mean the plan, not the roll, decides the delve.
  ProvingDef(
    id: 'tinkers_proving',
    title: "The Tinker's Proving",
    blurb: 'The Tinker on normal floors. Steady pips; the plan does the work.',
    seed: 131,
    character: 'tinker',
    difficulty: 'normal',
  ),
  // v0.119.0 The Seventh Way: the flintwright's own proving — four shards
  // on normal floors. Seed bot-win proven (hunt 2026-08-30: wins 1/2/4/9;
  // 9 picked for seed variety across the list).
  ProvingDef(
    id: 'flintwrights_proving',
    title: "The Flintwright's Proving",
    blurb:
        'The Flintwright on normal floors. Four small dice — the swarm '
        'does the work, if you let it.',
    seed: 9,
    character: 'flintwright',
    difficulty: 'normal',
  ),
  // v0.136.0 The Eighth Way: the runesmith's own proving. Seed bot-win
  // proven (sweep probe 2026-08-30: normal wins 1/2/4/5/6; 5 picked for
  // seed variety across the list).
  ProvingDef(
    id: 'runesmiths_proving',
    title: "The Runesmith's Proving",
    blurb:
        'The Runesmith on normal floors. One mark comes worked; make '
        'the second and third count.',
    seed: 5,
    character: 'runesmith',
    difficulty: 'normal',
  ),
  // v0.146.0 The Ninth Way: the bearer's own delve. Seed bot-win proven
  // (hunt 2026-08-30: bearer normal wins 8/16/17/19/20; 8 picked, unused
  // across the list). Blurb doubles as the kit's strategy hint.
  ProvingDef(
    id: 'bearers_proving',
    title: "The Bearer's Proving",
    blurb:
        'The Bearer on normal floors. Two dice carry everything — let '
        'the Echo teach the little one.',
    seed: 8,
    character: 'bearer',
    difficulty: 'normal',
  ),
  // v0.151.0 The Tenth Way (the v0.119 pattern, fourth use).
  ProvingDef(
    id: 'menders_proving',
    title: "The Mender's Proving",
    blurb:
        'The Mender on normal floors. The worst face stitches — spend '
        'the little dice and let the Coal pay its debt.',
    seed: 9,
    character: 'mender',
    difficulty: 'normal',
  ),
  // v0.159.0 The Eleventh Way (the v0.119 pattern, fifth use).
  ProvingDef(
    id: 'shieldwrights_proving',
    title: "The Shieldwright's Proving",
    blurb:
        'The Shieldwright on normal floors. The deep Aegis pays on the '
        'six — hold the marked die for the blows worth blunting.',
    seed: 10,
    character: 'shieldwright',
    difficulty: 'normal',
  ),
  // v0.163.0 The Twelfth Way (the v0.119 pattern, sixth use).
  ProvingDef(
    id: 'gilders_proving',
    title: "The Gilder's Proving",
    blurb:
        'The Gilder on normal floors. Both sixes pay coin — spend the '
        'gilded dice freely and let the shops do the forging.',
    seed: 4,
    character: 'gilder',
    difficulty: 'normal',
  ),
  // v0.170.0 The Thirteenth Way (the v0.119 pattern, seventh use).
  ProvingDef(
    id: 'cutlers_proving',
    title: "The Cutler's Proving",
    blurb:
        'The Cutler on normal floors. Two marks, two dice \u2014 the deep '
        'eight cuts, the ember six shields. Spend each where it pays.',
    seed: 14,
    character: 'cutler',
    difficulty: 'normal',
  ),
  // v0.172.0 The Fourteenth Way (the v0.119 pattern, eighth use).
  ProvingDef(
    id: 'colliers_proving',
    title: "The Collier's Proving",
    blurb:
        'The Collier on normal floors. Every die arrives worked \u2014 the '
        'blade cuts, the gilt pays, the mend holds. Nothing to build; '
        'everything to spend well.',
    seed: 6,
    character: 'collier',
    difficulty: 'normal',
  ),
  // v0.176.0 The Fifteenth Way (the v0.119 pattern, ninth use).
  ProvingDef(
    id: 'stokers_proving',
    title: "The Stoker's Proving",
    blurb:
        'The Stoker on normal floors. Three big coals and sixteen points '
        'of skin \u2014 every roll is plenty, every hit is dear.',
    seed: 12,
    character: 'stoker',
    difficulty: 'normal',
  ),
  // The Kept Hearth (the v0.119 pattern, tenth use) — the sixteenth and
  // LAST delver proving: the roster is closed, the list of delver
  // provings is complete. Seed 16 for the sixteenth chair (bot-win
  // pinned, unused by any other delver proving).
  ProvingDef(
    id: 'hearthkeepers_proving',
    title: "The Hearthkeeper's Proving",
    blurb:
        'The Hearthkeeper on normal floors. Every die sworn to one job '
        '\u2014 win with the pouch the fire dealt you.',
    seed: 16,
    character: 'hearthkeeper',
    difficulty: 'normal',
  ),
  // v0.179.0 The Laid Hedge — the seventeenth delver proving, first of
  // the second circle (the v0.119 pattern, eleventh use). Seed 17 for the
  // seventeenth chair (bot-win pinned, unused by any other delver
  // proving).
  ProvingDef(
    id: 'hedgers_proving',
    title: "The Hedger's Proving",
    blurb:
        'The Hedger on normal floors. Thin skin and a Thorn Band '
        '\u2014 make every blow against you cost.',
    seed: 17,
    character: 'hedger',
    difficulty: 'normal',
  ),
  // v0.108.0 The Proven Rules: the weekly's rules, kept. The rotation
  // moves on every Monday; these two stand still so a rule can be taken
  // deliberately, not just when the calendar deals it. Seeds bot-win
  // proven WITH the rule applied (tool hunt, 2026-08-29).
  ProvingDef(
    id: 'flint_proving',
    title: 'The Flint Proving',
    blurb:
        'The Kindler under Flint Week rules: every die rolls as a d4. '
        'Small, sharp, and mean.',
    // v0.114.0: seed 6 stopped being bot-winnable when the event deck grew
    // (The Cold Tales re-anchor); re-hunted under the same rule, seed 10.
    seed: 10,
    character: 'kindler',
    difficulty: 'normal',
    mutators: ['all_d4'],
  ),
  ProvingDef(
    id: 'cold_proving',
    title: 'The Cold Proving',
    blurb:
        'The Warden under Cold Camps rules: no rests on the map. What '
        'you carry is what you keep.',
    seed: 2,
    character: 'warden',
    difficulty: 'normal',
    mutators: ['no_rests'],
  ),
  // v0.117.0 The Winter Proving — the doubled week's pair as a set delve,
  // and a joke with teeth: the PEDDLER under Cold Quarter, the merchant
  // with nowhere to spend. Seed hunted WITH the pair applied (bot wins
  // 1/2/4; 4 picked for seed variety across the list).
  ProvingDef(
    id: 'winter_proving',
    title: 'The Winter Proving',
    blurb:
        'The Peddler under Cold Quarter rules: no shops and no rests. '
        'A merchant\'s fortune, and nowhere to spend it.',
    seed: 4,
    character: 'peddler',
    difficulty: 'normal',
    mutators: ['no_shops', 'no_rests'],
  ),
  ProvingDef(
    id: 'fifth_rung',
    title: 'The Fifth Rung',
    blurb: 'The Kindler at Ascension 5. The ladder starts to bite.',
    seed: 106,
    character: 'kindler',
    difficulty: 'normal',
    ascension: 5,
  ),
  ProvingDef(
    id: 'tenth_rung',
    title: 'The Tenth Rung',
    blurb: 'The Warden at Ascension 10. Halfway up, no shortcuts.',
    // v0.47.0: 200 -> 201 (enemy-pool growth re-rolled the seed; re-proven
    // bot-winnable, same hunt discipline as ash_summit's 908 -> 912).
    seed: 201,
    character: 'warden',
    difficulty: 'normal',
    ascension: 10,
  ),
  // v0.143.0 The Fifteenth Rung: the gap between the Tenth Rung and the
  // A20 badge, closed. Seed bot-win proven (hunt 2026-08-30: A15 wins
  // 14/20/24/34/36/39; 14 picked, unused across the list).
  ProvingDef(
    id: 'fifteenth_rung',
    title: 'The Fifteenth Rung',
    blurb: 'The Kindler at Ascension 15. Thin air; every mistake costs.',
    seed: 14,
    character: 'kindler',
    difficulty: 'normal',
    ascension: 15,
  ),
  ProvingDef(
    id: 'high_stakes',
    title: 'The High Stakes',
    blurb: 'The Gambler on hard floors. Elite pockets, richer loot.',
    seed: 500,
    character: 'gambler',
    difficulty: 'hard',
  ),
  ProvingDef(
    id: 'ash_summit',
    title: 'The Ash Summit',
    blurb: 'The Ascetic, hard, Ascension 15. The last name on the list.',
    seed: 912,
    character: 'ascetic',
    difficulty: 'hard',
    ascension: 15,
  ),
];

ProvingDef? provingById(String id) {
  for (final p in provings) {
    if (p.id == id) return p;
  }
  return null;
}
