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
  // v0.120.0 honesty edit: the roster grew (flintwright, v0.118.0). The
  // sequence contract is about ORDER, not frozen text — position 5 must
  // never state a count the picker disproves one screen away.
  'Sixteen keep this fire. Kindler, warden, gambler, ascetic, peddler, '
      'tinker, flintwright, runesmith, bearer, mender, shieldwright, '
      'gilder, cutler, collier, stoker, hearthkeeper. Each answers '
      'the delve.',
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
  // v0.120.0 The Third Cycle — what the deep remembers: the winter that
  // came through, the seventh chair, the book the hearth keeps. Append
  // only, as chartered.
  'One week in six, the delve deals two rules at once. The old hands '
      'call it the doubled week, and they plan their rests around it.',
  'A winter came through the delve once and never fully left. Where '
      'it settled, the stone still holds the pale light.',
  'The flintwright joined the fire last, with four dice and no '
      'apology. The counting has gone their way more often than not.',
  'The hearth keeps a book of everything felled, found, and walked. '
      'Embers open its pages; delving writes them.',
  'Cold camps are fights wearing a rest\'s clothes. The delve is not '
      'cruel about it — it says so on the way down.',
  'A proving is a delve that holds still. The delve does not mind '
      'being measured; it minds being guessed at.',
  'Every vista in the hearth window was carried up by somebody. The '
      'view is a trophy shelf, if you know how to read it.',
  'The dice in your bag were all cut from the same brick, whatever '
      'their size. Family, the smiths call a pool like that.',
  'Some floors have no shops and no mercy, and delvers walk them '
      'anyway. That is not bravery, the wardens say — it is practice.',
  'The third telling of a tale is the one that sticks. Ask the fire; '
      'it has been counting.',
  // v0.137.0 The Fourth Cycle: ten more — this pass sits with the anvil
  // and the calendar, the arcs the delve grew after the third telling.
  // Same charter: every line states one fact the game can prove.
  'The smith at these fires takes no ember and gives no name. Ask '
      'for a mark instead \u2014 two a delve is the smith\u2019s limit, '
      'and the smith does not bend it.',
  'Six runes come off that anvil: a blade\u2019s edge, an aegis\u2019s '
      'hold, a surge returned, an echo passed on, a mend, a little '
      'gold. The delve honors whoever has worked all six.',
  'The runesmith went down before the company had a name for going '
      'down, and came back marked. The smith has never once said '
      'whether they taught the runesmith, or the other way round.',
  'Every Monday the delve deals a rule \u2014 flint dice, elite '
      'floors, shut shops, a short road, cold camps. Take all of them '
      'once and you will have seen the whole rotation.',
  'Once a rotation the delve deals two rules at once. The wardens '
      'call that week the Cold Quarter, and they pack for it.',
  'The Codex seals nothing that matters: every record is free. What '
      'costs embers is only the deep\u2019s own words about itself.',
  'Some walls hold their color \u2014 moon-blue, frost-pale, forge-'
      'orange, rune-violet. A vista is the delve remembering how you '
      'earned its light.',
  'A tempered face pays on the roll it was made for and on no other. '
      'The anvil does not do luck; it does promises.',
  'The provings are delves that never change \u2014 same seed, same '
      'road \u2014 so a delver can be measured against the delve '
      'instead of against the dice.',
  'Sixteen chairs at this fire now, and the last one is filled. The '
      'delve answers each differently; that is the whole game, if you '
      'ask the fire.',
  // v0.165.0 The Fifth Cycle: ten more — the late chairs get their
  // tales at last (bearer, mender, shieldwright, gilder), then the
  // ledger's slower coins. Same charter: every line states one fact the
  // game can prove. Append only, as chartered.
  'The bearer keeps two dice only and the biggest life at this fire. '
      'Few rolls, grand promises — the delve has learned to take '
      'him at his word.',
  'The mender worked her mend into the Deep Coal\'s worst face, so '
      'the bad roll is the one that stitches. She calls that fairness, '
      'applied by hand.',
  'The shieldwright forged an aegis deep into a die before ever '
      'stepping down. The first floor has never once caught them '
      'unguarded.',
  'The gilder walked in with both sixes gilded. Coin on the roll, not '
      'on the kill — the peddler still has not forgiven the '
      'elegance of it.',
  'A deepened mark is the smith\'s second visit: the same rune, struck '
      'harder. Gilt struck deep pays three where it paid two.',
  'A whole delve fits in a short code. Hand it to a friend and the '
      'same floors, the same foes, the same luck will meet you both.',
  'Past embers, the hearth keeps marks — a slower coin. Wins, '
      'bosses, tales, records: everything honest adds a little, and '
      'nothing ever takes any away.',
  'Clear every proving on the list and the fire has a name waiting: '
      'the Proven. The list has grown before, and the name has kept '
      'every time.',
  'Each dawn the delve sets a small trial beside the week\'s rule. '
      'The fire counts both in its book, and the count only climbs.',
  'The fire has never run out of tales, and the delve has never run '
      'out of reasons to go down. One rest at a time, the book gets '
      'longer.',
  // The Sixth Cycle — the last chairs get their tales (cutler,
  // collier, stoker, hearthkeeper), then the closed fire's honors: the
  // roster, the Many-Handed, the crowned deep, the Worldflame, the last
  // proving. Same charter: every line states one fact the game can
  // prove. Append only, as chartered.
  'The cutler came down with an edge struck on one die and a guard on '
      'another. Ask which mattered more and the cutler taps whichever rolled '
      'last.',
  'The collier carries no relic, only three small marks worked into three '
      'plain dice. Everything the collier owns was smithed, not found.',
  'The stoker keeps three big coals and sixteen points of skin, nothing else. '
      'Every roll is plenty, the stoker says. Every hit is dear.',
  'The hearthkeeper\'s dice were never marked by the smith \u2014 they were '
      'forged to their work. One iron only strikes, one only wards, and one '
      'ember never rolls low.',
  'Sixteen chairs, and the fire is done making chairs. Whoever answers the '
      'delve now answers it as one of the sixteen.',
  'Win a delve from every chair and the fire has a second name waiting: the '
      'Many-Handed. Sixteen ways down, and the name asks all of them.',
  'Eight crowned things wait in the low places. The book keeps a page for '
      'each; the delve keeps the introductions.',
  'The ledger\'s ladder holds thirteen rungs, and the topmost is the '
      'Worldflame. No mark honestly earned ever slides back down.',
  'The provings end at the summit of ash \u2014 the longest road the delve '
      'holds still. Everything before it is practice for that stillness.',
  'Six times round now, this book of tales. The fire is not repeating itself, '
      'the old hands say. It is making sure.',
  // v0.179.0 — the second circle opens (append-LAST, same discipline).
  'When the sixteenth chair filled, the fire did not end \u2014 it drew '
      'a second circle. The hedger sat down first, and the thorns sat '
      'with them.',
  'The miller took the second chair of the second circle and set the '
      'stone turning. Grand promises grind slow \u2014 the small dice '
      'keep the fire fed meanwhile.',
  'The brewster hung a kettle over the second fire and said nothing. '
      'Some chairs are taken with a word, some with a full cup passed '
      'along the circle.',
  'The lamplighter came to the second fire last of the four and lit '
      'nothing \u2014 the circle was already burning. Some trades rest '
      'where the light is kept for them.',
  'The farrier came to the second fire with twelve hearts and iron '
      'that never rolls less. The circle asked no proof \u2014 sure '
      'iron is its own word.',
  'The glover keeps one glove keen and one glove stout, and will not '
      'say which hand the delve fears more. The bare hand, say those '
      'who have watched it deal.',
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
