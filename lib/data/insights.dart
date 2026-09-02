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
    // v0.180.0 The Honest Road: the old line ('Fight the low-HP enemies
    // first when a path branches') coached a read the map never offers —
    // nodes show their KIND, never an enemy or its HP. Say what the map
    // does show. Rest fires and events can sit on floors 2–3 (map_gen:
    // rests have no layer gate, eventFromLayer 2); elites cannot (4+), so
    // the early bucket never mentions them.
    'Every room ahead is marked on the map. A road with a rest fire on it '
        'forgives a bad fight; a road of nothing but fights does not.',
  ],
  'mid': [
    'Rest before an elite, not after — you choose the fight, so choose it healthy.',
    'Spend gold: a shop die now beats a hoard of coins on the boss floor.',
    'Skip a reward that dilutes your pool — fewer, stronger dice roll better.',
    // v0.148.0 The Taught Fire: the anvil finally speaks at death.
    'The anvil at a rest fire is not a detour. A mark on one face pays '
        'every floor after it.',
    'Relics stack. Two small blocks each turn outlast one big swing.',
  ],
  'late': [
    // v0.148.0 The Taught Fire.
    'An Aegis mark on a big face turns an elite\u2019s opener into a '
        'plan instead of a surprise.',
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
  // v0.180.0 The Named Deaths: the five bosses added since v0.22.0 fell
  // through to the generic 'boss' bucket — a Bellows death was coached with
  // "never swing into a raised guard", which for the Bellows is every turn.
  // Same rules as above: number-free, block-timing honest (a shown guard
  // walls the NEXT player turn; the very first turn always lands bare),
  // exactly 3 lines so the loot-stream draw shape is unchanged. Each claim
  // is pinned against the pattern in test/named_deaths_test.dart.
  'boss_cinder_hierophant': [
    // Pattern: attack, block, attack, attack+block, attack (heaviest).
    'The Hierophant guards twice in five beats, never twice running: the '
        'turn after each guard is walled, the rest land full.',
    'Its fifth beat is the heaviest by far and follows a guard: spend that '
        'turn on block, then the cycle starts soft again.',
    'Five beats is a long cycle. Count it once on the first loop and spend '
        'your damage on the second.',
  ],
  'boss_the_bellows': [
    // Pattern: attack+block on every beat — no open turn exists after the first.
    'The Bellows guards every beat — there is no open turn to wait for. '
        'Only pips past its guard land: bring more, not later.',
    'Your first turn is the only one that meets a bare Bellows. Open with '
        'your best attack dice.',
    'It swings every beat too. Block the hits you cannot afford and race '
        'the rest — patience feeds it.',
  ],
  'boss_ashfall_twins': [
    // Pattern: attack, attack, block, attack (heaviest).
    'The Twins guard right before their heaviest swing. The turn after the '
        'guard is walled and ends in that hit: all block, no race.',
    'Two open beats lead each cycle. That is where your damage goes.',
    'Their heaviest hit closes the cycle and the next beat is open — '
        'survive the swing and the answer is already yours.',
  ],
  'boss_slag_regent': [
    // Pattern: block, block, attack (heaviest).
    'The Regent raises two guards, then swings once. Only the turn after its '
        'swing lands on bare stone — hit then, hard.',
    'The turn after its first guard is dead air: your dice are walled and no '
        'hit is coming. Reroll, forge, breathe.',
    'The turn it shows the swing, its second guard is still up. Block that '
        'turn instead of racing it.',
  ],
  'boss_hearthless_king': [
    // Pattern: attack, block.
    'The King swings, then guards. The turn it shows its shield is your open '
        'turn — no hit coming and no wall up yet.',
    'The turn it shows the swing, last beat\u2019s guard still stands. Block '
        'that turn; race the other.',
    'Two beats, no surprises. Alternate block and attack in step with it '
        'and the fight is a rhythm, not a gamble.',
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
