// lib/data/crowns.dart — v0.180.0 The Fallen Crown.
//
// One sentence per boss for the won screen. Until now a win said "The Ember
// is yours" and the delver's name, and never once named what had just been
// put down; the death screen, by contrast, has spoken in every boss's own
// words since v0.163. Each line answers the boss's Codex entry (taxes,
// the office, the jury, the causeway…) and states nothing the sim cannot
// prove. Chosen by boss id — bossForSeed(runSeed) — so it draws no RNG.
//
// Rules (test/fallen_crown_test.dart): one line for every boss and no
// other enemy; ≤ 110 characters; the store banned-word sweep; number words
// match the boss patterns they describe.
const Map<String, String> crownLines = {
  'ember_tyrant':
      'The Tyrant\'s four beats fall silent. Its taxes go unpaid, and the '
      'ember goes up the road with you.',
  'ashen_colossus':
      'The Colossus stops at last, where you told it to. What it carried '
      'down, you carry up.',
  'pyre_matriarch':
      'The Matriarch\'s three blows fall short. The brood she tended goes '
      'untended tonight.',
  'cinder_hierophant':
      'The Hierophant\'s liturgy ends mid-verse. The coals have one less '
      'thing to believe.',
  'the_bellows':
      'The Bellows bursts and the office stands empty. The deep delve '
      'holds its breath for you.',
  'ashfall_twins':
      'The Twins\' argument is settled at last: the jury went home with '
      'the ember.',
  'slag_regent':
      'The Regent\'s audience ends the other way. The causeway lies open, '
      'and no crown is coming back for it.',
  'hearthless_king':
      'The King\'s clock stops between strike and guard. The hearth he '
      'banked burns for someone else now.',
};
