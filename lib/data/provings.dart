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
