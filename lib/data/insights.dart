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
  'boss': [
    // Number-free on purpose: the exact amount shifts with difficulty and
    // ascension, and a death-screen tip must never lie (§Ethics honesty).
    "The Tyrant's turn 4 is its heaviest hit — enter that turn with block banked.",
    'The Tyrant blocks on turn 2; hold your damage and strike turn 3.',
    'Bring healing into the boss: its 4-beat cycle out-damages a raw race.',
  ],
  'generic': [
    'Randomness picks what you roll, never how your played dice resolve.',
    'Every death banks embers — the next delve starts stronger.',
  ],
};

String insightBucket(int layer, bool bossDeath) {
  if (bossDeath) return 'boss';
  if (layer <= 3) return 'early';
  if (layer <= 6) return 'mid';
  return 'late';
}
