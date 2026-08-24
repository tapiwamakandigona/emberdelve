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

  const ProvingDef({
    required this.id,
    required this.title,
    required this.blurb,
    required this.seed,
    required this.character,
    required this.difficulty,
    this.ascension = 0,
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
    seed: 200,
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
    seed: 908,
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
