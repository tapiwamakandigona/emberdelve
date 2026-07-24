// data/insights.dart — Death-screen insight lines (fair-death pillar).
// CONTENT AS DATA, ZERO LOGIC.
//
// On run_lost the run layer picks ONE line deterministically (loot stream)
// from the bucket matching the death context, so every death teaches something
// concrete and honest — never a taunt (docs/spec.md §Ethics).
//
// Buckets:
//   early   — died on layers 2–3 (fundamentals)
//   mid     — layers 4–6 (build/economy)
//   late    — layers 7–8 (elite/boss prep)
//   boss    — died to the boss
//   generic — fallback

const Map<String, List<String>> insights = {
  'early': [
    'Block the turn a big hit is shown — enemy intent never lies.',
    'A die assigned to block is never wasted; survival buys damage later.',
    'Fight the low-HP enemies first when a path branches.',
  ],
  'mid': [
    'Rest before an elite, not after — you choose the fight, so choose it healthy.',
    'Spend gold: a shop die now beats a hoard of coins on the boss floor.',
    'Skip a reward that dilutes your pool — fewer, stronger dice roll better.',
    'Relics stack. Two small blocks each turn outlast one big swing.',
  ],
  'late': [
    'Forge duplicates upward at rests; a d8 floor beats three shaky d6s.',
    'Elites telegraph a cycle — count to their big hit and block exactly then.',
    'Save an attack die for the turn the enemy drops its guard.',
  ],
  // v0.4 boss variety: each boss gets its own honest coaching bucket (a
  // death-screen tip must never lie — §Ethics honesty — and a Tyrant tip
  // would lie about the Colossus). 'boss' stays as the generic fallback for
  // any boss id without a dedicated bucket. All buckets keep exactly 3 lines
  // so the seeded loot-stream draw shape is unchanged.
  'boss': [
    'Every boss telegraphs a fixed cycle — learn it on the first loop, '
        'spend your damage on the second.',
    'Never swing into a raised guard; the open beat always comes back around.',
    'Bring healing into the boss: a long cycle out-damages a raw race.',
  ],
  'boss_ember_tyrant': [
    // Number-free on purpose: the exact amount shifts with difficulty and
    // ascension, and a death-screen tip must never lie (§Ethics honesty).
    "The Tyrant's turn 4 is its heaviest hit — enter that turn with block banked.",
    // Block timing (sim-verified): a block intent protects the enemy during
    // the FOLLOWING player turn. The Tyrant shows block on turn 2 and
    // attack+block on turn 3, so player turns 3 and 4 swing into a raised
    // guard while turns 1-2 hit an unguarded boss. The old line said the
    // exact opposite ("hold your damage and strike turn 3") — coaching the
    // worst possible line on the death screen (§Ethics: insights never lie).
    'The Tyrant shields through the middle of its cycle — pour damage into '
        'the early beats, never into a raised guard.',
    'Bring healing into the boss: its 4-beat cycle out-damages a raw race.',
  ],
  'boss_ashen_colossus': [
    // Block timing (sim-verified, same rule as above): the Colossus guards on
    // beats 1 and 2 of its 3-beat cycle, so the only unguarded player turn is
    // the one right after its giant swing.
    'The Colossus guards two beats in three — the open turn is the one right '
        'after its giant swing lands.',
    'Its heaviest hit closes the cycle; bank block early so you are still '
        'standing when it comes.',
    'Racing a wall loses. Hold your burst for the open beat and block the rest.',
  ],
  'boss_pyre_matriarch': [
    'The Matriarch never guards — every one of your turns lands full. '
        'Make each pip count and race her down.',
    'Her flame climbs each beat, then resets. Block or heal into the crest, '
        'not the start.',
    'No shield to wait out: slow, careful play just feeds her tempo.',
  ],
  'generic': [
    'Randomness picks what you roll, never how your played dice resolve.',
    'Every death banks embers — the next delve starts stronger.',
  ],
};

String insightBucket(int layer, bool bossDeath, {String? bossId}) {
  if (bossDeath) {
    final keyed = 'boss_$bossId';
    return insights.containsKey(keyed) ? keyed : 'boss';
  }
  if (layer <= 3) return 'early';
  if (layer <= 6) return 'mid';
  return 'late';
}
