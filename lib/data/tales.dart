// lib/data/tales.dart — v0.96.0 "The Hearth Tale": the fire talks back.
//
// Our first outside review (2026-08-23) said "I still don't understand
// what's a delve" — AFTER finishing easy mode with the one-shot
// whats_a_delve tip live since v0.30.0. One card at one moment is not how
// a world sinks in. So the world now arrives as a drip: every rest fire
// tells one short tale, in a fixed order across the player's whole
// lifetime (persisted in MetaState.hearthTalesHeard, monotonic, cloud-max
// merged), then the sequence comes round again.
//
// Copy charter: each tale is 1–2 sentences, states one fact about the
// world (what a delve is, what embers are, who the delvers are, what
// relics mean, what waits below), and passes the docs/spec.md §5 ethics
// blacklist like all player-facing copy.
//
// v0.100.0 The Second Cycle: ten more tales — the arc's second pass sits
// with each delver in turn, then returns to what the delve keeps. The
// Hearthgold milestone is FROZEN at the first cycle (see hearthgoldTales);
// growing this list must never re-lock an earned vista.

/// Fixed telling order. Append only — the sequence is a story arc, and
/// players mid-arc must not see it reshuffle under them.
const List<String> hearthTales = [
  'They say the first delver went down with nothing but a lantern, '
      'and came home with an ember that would not go out.',
  'A delve is the whole descent — every floor, every fight, every '
      'fire like this one — counted from the first step to the last.',
  'The floors below were not built. They grew, the way a coal grows '
      'its ash, and no two delves find them the same.',
  'Embers are the deep paying its debts. Carry them home and the '
      'hearth burns brighter for everyone.',
  'Six keep this fire now. Kindler, warden, gambler, ascetic, '
      'peddler, tinker — the delve answers each of them differently.',
  'The relics you find were not lost. They were left — by delvers '
      'who wanted the next one through to go further.',
  'Every fire on the way down is borrowed from the hearth above. '
      'That is why resting here feels like home.',
  'Deep enough down, the dark wears a crown. Those who came back '
      'from that floor speak softly of it.',
  'The songs the gramophone keeps were all heard first in the delve. '
      'Someone had to climb home humming them.',
  'When a delve ends, the deep keeps nothing but the story. The rest '
      '— the embers, the name you earned — comes home with you.',
  // v0.100.0 The Second Cycle — the arc comes round richer: one tale per
  // delver, then the things the delve keeps. Append only, as chartered.
  'The kindler was a hearth-tender first. She went down because the '
      'coals told her where they came from, and she wanted to see.',
  'The warden held a door once, alone, until everyone was through. '
      'The delve has been trying to move him ever since.',
  'The gambler counts the pips before the dice land. Not to cheat — '
      'to know what luck owes, and what it never promised.',
  'The ascetic carries nothing she has not earned twice. The deep '
      'respects that, in its way, and tests it anyway.',
  'The peddler has sold to every floor and been paid in every coin. '
      'Ask what embers are worth and he only smiles.',
  'The tinker took a temper stone apart to see why it worked. It '
      'worked better after — that is the whole of her heresy.',
  'Forge fires and hearth fires are cousins. One remakes the die in '
      'your hand; the other remakes the delver holding it.',
  'The crowned dark was a delver once, some say. Others say the dark '
      'only wears what the proud left behind.',
  'No map survives the delve, so the delve is the map. Walk it and '
      'it walks in you — that is what the old ones mean by delving.',
  'The fire has told these tales before and will tell them again. '
      'A story is a coal: it keeps by being passed along.',
];

/// v0.100.0: the Hearthgold milestone, FROZEN at the first cycle's length.
/// v0.98.0 gated the vista on hearthTales.length, which read as honest but
/// hid a regression: a grown tale list would RE-LOCK an already-earned
/// vista (derived unlocks must never move backward). Earned milestones
/// freeze; only the tales keep growing.
const int hearthgoldTales = 10;

/// The tale the fire tells after [heard] hollows have already been left:
/// sequential on the first pass, then the arc comes round again.
String hearthTale(int heard) =>
    hearthTales[(heard < 0 ? 0 : heard) % hearthTales.length];
