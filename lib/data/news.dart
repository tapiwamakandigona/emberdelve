// lib/data/news.dart — The Hearthside Post (v0.15.0): version-keyed
// "what's new" notes, CONTENT AS DATA, ZERO LOGIC beyond lookups.
//
// Charter (docs/improvements/v0.15.0-hearthside-post-design.md):
//   • One entry per release, 2–4 short player-voiced lines distilled from
//     docs/releases/vX.md — same campfire voice, always a thank-you.
//   • Shown ONCE on the title screen after an update, dismissed with one
//     tap, re-readable forever from Settings ("Past posts"). Never a badge,
//     never a nag, never a link to spend money (§Ethics).
//   • Ships in the binary — no remote fetch, offline-first.

class NewsEntryDef {
  final String version; // dotted version name, e.g. '0.15.0'
  final String title; // the release's name, e.g. 'The Hearthside Post'
  final List<String> lines; // 2–4 short player-voiced lines
  const NewsEntryDef({
    required this.version,
    required this.title,
    required this.lines,
  });
}

/// The version NAME this binary ships as. Single source of truth for the
/// news panel; MUST equal pubspec.yaml's `version:` name — pinned by
/// test/news_test.dart so the two can never drift apart.
const String currentAppVersion = '0.136.0';

/// Newest first. Backfilled to v0.13.0 — older releases predate the Post.
const List<NewsEntryDef> newsEntries = [
  NewsEntryDef(
    version: '0.136.0',
    title: 'The Eighth Way',
    lines: [
      'The Runesmith\u2019s Proving joins the list \u2014 fifteen '
          'provings now \u2014 with two honors: Rune-Sharp, and Eight '
          'Ways Down.',
      'Seven Ways Down stays earned as it was. New counts get new names.',
    ],
  ),
  NewsEntryDef(
    version: '0.135.0',
    title: 'The Runesmith',
    lines: [
      'An eighth delver: the Runesmith arrives with Surge already '
          'worked into a Deep Coal \u2014 lean at 26 HP, and the anvil '
          'answers them first.',
      '900 embers at the fire. The eighth chair is earned.',
    ],
  ),
  NewsEntryDef(
    version: '0.134.0',
    title: 'The Runemark',
    lines: [
      'A tenth vista: work every rune the anvil offers and the delve '
          'keeps the marks \u2014 cold, violet runeglass light.',
      'The Six Marks summit, painted on the stone.',
    ],
  ),
  NewsEntryDef(
    version: '0.133.0',
    title: 'The Six Marks',
    lines: [
      'The Ledger now remembers which runes you have tempered \u2014 '
          'and honors the third and the sixth.',
      'Win or lose, forge work counts.',
    ],
  ),
  NewsEntryDef(
    version: '0.132.0',
    title: 'The Second Mark',
    lines: [
      'The anvil gives twice now: two tempers a delve, up from one.',
      'Pair the marks \u2014 a blade with an echo, a mend with a '
          'gilt \u2014 and make the forge a plan, not a pick.',
    ],
  ),
  NewsEntryDef(
    version: '0.131.0',
    title: 'The Written Rules',
    lines: [
      'The Codex gains THE RULES: six pages on the weekly '
          'calendar \u2014 what each rule is, in the delve\u2019s '
          'own words.',
      'Ten embers a page, like every place the world describes.',
    ],
  ),
  NewsEntryDef(
    version: '0.130.0',
    title: 'The Gilded Face',
    lines: [
      'A sixth temper rune: Gilt \u2014 on that face, the assignment '
          'pays 2 gold, attack or block alike.',
      'The economy temper. Six runes, six ways to mark a die.',
    ],
  ),
  NewsEntryDef(
    version: '0.129.0',
    title: 'The Earned Titles',
    lines: [
      'Two new epithets: the Tempered, for ten marked faces \u2014 '
          'and the Weathered, for every rule the Weekly deals.',
      'Worn under the name, earned by delving, never sold.',
    ],
  ),
  NewsEntryDef(
    version: '0.128.0',
    title: 'The Smith\u2019s Shelf',
    lines: [
      'Three new cosmetics from the forge: the Forgesoot dye, and '
          'the Tempered and Runeglass dice.',
      'Real prices up front, pure paint as ever \u2014 faces, rolls '
          'and odds never change.',
    ],
  ),
  NewsEntryDef(
    version: '0.127.0',
    title: 'The Full Rotation',
    lines: [
      'The Weekly now remembers which rules you have beaten \u2014 '
          'all six, from Flint Week to the Cold Quarter.',
      'A quiet tally on the title, and two honors: Rule Taken and '
          'The Full Rotation. Real wins, as ever.',
    ],
  ),
  NewsEntryDef(
    version: '0.126.0',
    title: 'The Forgelight',
    lines: [
      'A ninth vista: Forgelight \u2014 the delve lit from below, the '
          'way a smithy holds its glow.',
      'Earned at ten tempered faces, the forge arc\u2019s own window. '
          'Earned by delving, never sold.',
    ],
  ),
  NewsEntryDef(
    version: '0.125.0',
    title: 'The Tempered Hand',
    lines: [
      'The forge\u2019s work now counts: every face you temper joins a '
          'lifetime tally in the Ledger.',
      'Two honors with it \u2014 The Marked Face and Well Tempered. '
          'Banked win or lose; the work was real either way.',
    ],
  ),
  NewsEntryDef(
    version: '0.124.0',
    title: 'The Mender\u2019s Mark',
    lines: [
      'A fifth temper rune: Mend \u2014 on that face, mend 1 HP when '
          'the die is assigned, either verb.',
      'The sustain temper the forge was missing. A full delver mends '
          'nothing; the rune says so itself.',
    ],
  ),
  NewsEntryDef(
    version: '0.123.0',
    title: 'The Crowned Company',
    lines: [
      'Hard-mode wins are now charted per delver \u2014 in the picker '
          'tally, the Ledger roster, and two new honors.',
      'Three Crowns asks three delvers; the Crowned Company asks '
          'them all. Real counters, as ever.',
    ],
  ),
  NewsEntryDef(
    version: '0.122.0',
    title: 'The Spoken Delve',
    lines: [
      'The run\'s choices now speak: reward cards, boon cards, the '
          'temper sheet, and the shop all carry screen-reader labels.',
      'Nothing moved and nothing changed for sighted play \u2014 the '
          'delve just learned to say what it shows.',
    ],
  ),
  NewsEntryDef(
    version: '0.121.0',
    title: 'The Waymark Line',
    lines: [
      'The title screen now names your nearest unearned honor \u2014 '
          'one quiet line, real counts, tap for the Ledger.',
      'It appears only once real progress exists. A goal you have '
          'not started is not a goal you are close to.',
    ],
  ),
  NewsEntryDef(
    version: '0.120.0',
    title: 'The Third Cycle',
    lines: [
      'Ten new hearth tales \u2014 the fire has caught up with the '
          'winter, the doubled week, and the seventh chair.',
      'The arc now runs three cycles of ten before it comes round '
          'again. Hearthgold stays earned exactly as it was.',
    ],
  ),
  NewsEntryDef(
    version: '0.119.0',
    title: 'The Seventh Way',
    lines: [
      'The Flintwright gets their proving \u2014 four shards on normal '
          'floors \u2014 and two Ledger honors to match.',
      'Six Ways Down stays earned as it was: recognition never '
          're-prices. Seven Ways Down is its own name.',
    ],
  ),
  NewsEntryDef(
    version: '0.118.0',
    title: 'The Flintwright',
    lines: [
      'A seventh delver: the swarm \u2014 the only delver who starts '
          'with FOUR dice, and none of them grand.',
      '750 embers at the hearth. Balance swept before shipping; every '
          'other delver\'s delves are untouched.',
    ],
  ),
  NewsEntryDef(
    version: '0.117.0',
    title: 'The Winter Proving',
    lines: [
      'A 13th proving: the Peddler under Cold Quarter \u2014 a '
          'merchant\'s fortune, and nowhere to spend it.',
      'The doubled week\'s pair, held still so you can measure '
          'yourself against it any day.',
    ],
  ),
  NewsEntryDef(
    version: '0.116.0',
    title: 'The Spoken Dice',
    lines: [
      'THE DICE close the Codex: one story per base cut, from the '
          'flint shard to the molten core.',
      '97 entries now. Flavor only \u2014 what a die does stays printed '
          'on its face, free.',
    ],
  ),
  NewsEntryDef(
    version: '0.115.0',
    title: 'The Delver\'s Window',
    lines: [
      'Vistas are now worn per delver \u2014 bind a light to each, and '
          'the delve repaints for whoever walks it.',
      'The delver\'s card wears their own window too. Unlocks stay '
          'global; nothing already earned moves.',
    ],
  ),
  NewsEntryDef(
    version: '0.114.0',
    title: 'The Cold Tales',
    lines: [
      'Three new rooms in the event deck: a frozen stall, a wintered '
          'die, a meltwater pool \u2014 the cold left its mark.',
      '53 events now; a night of runs repeats itself even less.',
    ],
  ),
  NewsEntryDef(
    version: '0.113.0',
    title: 'The Cold Honors',
    lines: [
      'Two Ledger honors for the doubled week: The First Winter (one '
          'Ember claimed) and Thrice Wintered (three).',
      'Recognition only, as every honor \u2014 they grant nothing and '
          'read real banked wins.',
    ],
  ),
  NewsEntryDef(
    version: '0.112.0',
    title: 'The Frostvein',
    lines: [
      'An eighth vista: Frostvein \u2014 pale, wintered stone, the '
          'first vista the Weekly feeds.',
      'Earned by claiming the Ember on a doubled week. Cosmetic as '
          'ever \u2014 earned by delving, never sold.',
    ],
  ),
  NewsEntryDef(
    version: '0.111.0',
    title: 'The Doubled Week',
    lines: [
      'One week per cycle the Weekly deals a named pair: Cold Quarter '
          '\u2014 no shops and no rests, declared up front.',
      'Same charter as every weekly: one shared delve for everyone, '
          'and a missed week is simply a missed week.',
    ],
  ),
  NewsEntryDef(
    version: '0.110.0',
    title: 'The Named Company',
    lines: [
      'The Codex gains THE COMPANY: one story per delver, priced like '
          'common lore, between the world and the enemies.',
      'Flavor only, as ever — kits and numbers stay on the picker, '
          'free.',
    ],
  ),
  NewsEntryDef(
    version: '0.109.0',
    title: 'The Coming Rule',
    lines: [
      'Once this week\'s Weekly Delve is played, the title screen '
          'states next Monday\'s rule beneath the recap.',
      'An appointment, not a nag: a fact of the rotation, with no '
          'countdown and no pressure.',
    ],
  ),
  NewsEntryDef(
    version: '0.108.0',
    title: 'The Proven Rules',
    lines: [
      'Two new Provings keep the weekly rules standing: the Flint '
          'Proving (every die a d4) and the Cold Proving (no rests).',
      'The rotation moves on every Monday; these stand still, so a '
          'rule can be taken deliberately. Both machine-proven winnable.',
    ],
  ),
  NewsEntryDef(
    version: '0.107.0',
    title: 'The Unwritten Feats',
    lines: [
      'Seven new feats in the Ledger for the systems that grew after '
          'it: weeklies, the Codex, hearth tales, settled scores, and '
          'the breadth of the bestiary.',
      'Recognition only, as ever \u2014 counted from what you already '
          'did, granting nothing but the mark.',
    ],
  ),
  NewsEntryDef(
    version: '0.106.0',
    title: 'The Cold Camps',
    lines: [
      'A fifth Weekly rule joins the rotation: Cold Camps \u2014 no '
          'rests on the map, every camp is a fight instead.',
      'Healing comes only from shops, events, and what you carry. '
          'The rule is declared up front, as always.',
    ],
  ),
  NewsEntryDef(
    version: '0.105.0',
    title: 'The Delver\u2019s Line',
    lines: [
      'Open one delver\u2019s page on the Ledger and their lifetime is '
          'written under the chips: delves, wins, best floor.',
      'Read from the counters that never forget \u2014 the remembered '
          'list keeps 30, the line keeps all of it.',
    ],
  ),
  NewsEntryDef(
    version: '0.104.0',
    title: 'The Delve Itself',
    lines: [
      'The Codex now opens on THE WORLD: eight place entries, and '
          '\u2018what is a delve?\u2019 answered first.',
      'Cheapest lore in the book at 10 embers. Enemy intents and relic '
          'effects stay readable in play, free, as ever.',
    ],
  ),
  NewsEntryDef(
    version: '0.103.0',
    title: 'The Marked Week',
    lines: [
      'Weekly delves now wear their mark in the Ledger, rule named \u2014 '
          'weekly \u00b7 Flint Week \u00b7 \u2026',
      'Modded runs offer no Delve Code: a code cannot carry the rule, '
          'and a code that rebuilds a different run is no code at all.',
    ],
  ),
  NewsEntryDef(
    version: '0.102.0',
    title: 'The Painted Trace',
    lines: [
      'The Delver\'s Card now paints its own floor grid \u2014 the same '
          'card on every phone, no matter whose emoji it wears.',
      'The claimed Ember\'s cell carries a gold ring.',
    ],
  ),
  NewsEntryDef(
    version: '0.101.0',
    title: 'The Delver\'s Page',
    lines: [
      'The Ledger\'s recent delves gained pages: read every delve, or '
          'one delver\'s alone.',
      'The sounding line redraws for the open page.',
    ],
  ),
  NewsEntryDef(
    version: '0.100.0',
    title: 'The Second Cycle',
    lines: [
      'Ten new hearth tales: the fire\'s second pass sits with each '
          'delver in turn, then returns to what the delve keeps.',
      'The Hearthgold stays a first-cycle milestone \u2014 earned is '
          'earned.',
    ],
  ),
  NewsEntryDef(
    version: '0.99.0',
    title: 'The Colored Card',
    lines: [
      'The Delver\'s Card now keeps the delve\'s light: your chosen '
          'vista washes the card you share.',
      'Your run, your colors \u2014 on the card too.',
    ],
  ),
  NewsEntryDef(
    version: '0.98.0',
    title: 'The Hearthgold',
    lines: [
      'A seventh vista, earned by listening: hear every tale the fire '
          'tells and the delve keeps the fire\'s gold.',
      'The first vista that brightens \u2014 and the summary counts your '
          'tales toward it.',
    ],
  ),
  NewsEntryDef(
    version: '0.97.0',
    title: 'The Counted Forge',
    lines: [
      'Forge rows now state what actually changes \u2014 the die\u2019s real '
          'numbers before and after, in the same words the reward picker uses.',
      'No more forging on faith.',
    ],
  ),
  NewsEntryDef(
    version: '0.96.0',
    title: 'The Hearth Tale',
    lines: [
      'The rest fire talks back now \u2014 one short tale of the delve '
          'at every hollow, told in order across your whole journey.',
      'Sit a while. The world explains itself, one fire at a time.',
    ],
  ),
  NewsEntryDef(
    version: '0.95.0',
    title: 'The Known Relic',
    lines: [
      'Every relic now carries its own icon \u2014 fourteen of them had '
          'been sharing the same borrowed lantern.',
      'The satchel, the shop, and the pause sheet all read at a glance.',
    ],
  ),
  NewsEntryDef(
    version: '0.94.0',
    title: 'The Deep Wardrobe',
    lines: [
      'Two new dyes hang on the rack \u2014 Emberheart, red as the '
          'coal\u2019s own heart, and Glowmere, drawn from the still pools.',
      'Three new titles wait to be earned: the Deepdrawn, the Measured, '
          'and the Six-Handed. Real feats, as ever \u2014 never sold.',
    ],
  ),
  NewsEntryDef(
    version: '0.93.0',
    title: 'The Pictured Satchel',
    lines: [
      'Your relic satchel shows each relic\u2019s picture beside its '
          'effect — the same faces you met at the shop.',
      'Pickup order and the starting-relic tag stay as they were.',
    ],
  ),
  NewsEntryDef(
    version: '0.92.0',
    title: 'The Counted Draught',
    lines: [
      'Event choices that heal now say exactly how much — the last '
          'percentage in the delve is gone.',
      'A heal that would do nothing says so before you pick it.',
    ],
  ),
  NewsEntryDef(
    version: '0.91.0',
    title: 'The Legible Stall',
    lines: [
      'The Ashmonger tidied the stall: wares now state their business in a '
          'full line instead of a cramped column.',
      'On narrow screens a ware\u2019s name fits itself to its shelf '
          'rather than breaking apart.',
    ],
  ),
  NewsEntryDef(
    version: '0.90.0',
    title: 'The Counted Ration',
    lines: [
      'The Ashmonger now tells the truth about Field Rations — the exact '
          'heal you would get, overheal counted in.',
      'At full health the rations say so plainly, so no gold is wasted on '
          'a heal that does nothing.',
    ],
  ),
  NewsEntryDef(
    version: '0.89.0',
    title: 'The Counted Rest',
    lines: [
      'The rest button now prints the exact heal — amount and where it '
          'lands — instead of a percentage to work out yourself.',
      'Rest relics like the Bedroll are counted in, so their worth shows '
          'at the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.88.0',
    title: 'The Coming Vista',
    lines: [
      'When a run moves you nearer to a locked vista, the summary says so '
          'with the real numbers.',
      'Only when the counter actually moved — a quiet fact, never a nag.',
    ],
  ),
  NewsEntryDef(
    version: '0.87.0',
    title: 'The Guttering Foe',
    lines: [
      'A foe close to falling shows it in the fight: its bar turns gold and '
          'the caption says NEARLY SPENT.',
      'Same rule as the danger music — now visible while you can act on it.',
    ],
  ),
  NewsEntryDef(
    version: '0.86.0',
    title: "The Foe's Last Thread",
    lines: [
      'A loss that fell one good turn short says so: the summary names how '
          'little the foe had left.',
      'The mirror of the Narrow Climb — same rule, their side.',
    ],
  ),
  NewsEntryDef(
    version: '0.85.0',
    title: 'The Narrow Climb',
    lines: [
      'A win that ended in the red says so on the summary — quiet, factual, '
          'and only when it was truly close.',
      'Same rule the danger music already keeps.',
    ],
  ),
  NewsEntryDef(
    version: '0.84.0',
    title: 'The Song Credit',
    lines: [
      'The first time a song ever plays, its name appears — once, at the '
          'moment you hear it.',
      'Eight songs, eight credits, a lifetime.',
    ],
  ),
  NewsEntryDef(
    version: '0.83.0',
    title: 'The Depth Gauge',
    lines: [
      'The map now states your floor as you delve — Floor N of M, right '
          'where you pick the descent.',
      'No more counting rows by hand.',
    ],
  ),
  NewsEntryDef(
    version: '0.82.0',
    title: 'The Farthest Lantern',
    lines: [
      'The map now marks your lifetime deepest floor — a thin gold line '
          'where you last turned back.',
      'Past the lantern is new depth. It moves only when you do.',
    ],
  ),
  NewsEntryDef(
    version: '0.81.0',
    title: 'The Retraced Page',
    lines: [
      'Any remembered delve in the Ledger now offers the road back — tap '
          'the replay mark to walk the same halls again.',
      'Same seed, same delver, same map. The one that killed you is '
          'waiting.',
    ],
  ),
  NewsEntryDef(
    version: '0.80.0',
    title: 'The Plumb Line',
    lines: [
      'The Ledger now states your deepest floor ever — one lifetime row, '
          'plain and absolute.',
      'The sounding line draws the arc of your recent delves; the plumb '
          'line is the number you would quote.',
    ],
  ),
  NewsEntryDef(
    version: '0.79.0',
    title: 'The Settled Score',
    lines: [
      'The run that finally fells your old foe now says so — one gold '
          'line on the summary, once per foe, ever.',
      'The score never reopens and nothing rides on it. The felling is '
          'the reward.',
    ],
  ),
  NewsEntryDef(
    version: '0.78.0',
    title: 'The Old Foe',
    lines: [
      'The Ledger now names the old foe — the enemy that has ended more '
          'of your delves than any other, with its tally.',
      'Stated flatly from your own record. Two falls make a foe; the '
          'Ledger holds no grudge and sets no errand.',
    ],
  ),
  NewsEntryDef(
    version: '0.77.0',
    title: 'The Sounding Line',
    lines: [
      'The Ledger now draws the depth of your remembered delves — a small '
          'chart above Recent Delves, oldest to newest, wins in ember.',
      'Every bar is a real run from your own record. Two delves make a '
          'line; the chart waits until you have them.',
    ],
  ),
  NewsEntryDef(
    version: '0.76.0',
    title: 'The New Song',
    lines: [
      'When a delve is the first to hear a track, the summary now says '
          'so — one quiet line, however many songs arrived.',
      'Every song named is already on the Gramophone shelf, ready to '
          'play or to pin at the hearth.',
    ],
  ),
  NewsEntryDef(
    version: '0.75.0',
    title: 'The Hearth Song',
    lines: [
      'A heard Gramophone track can now be pinned as the hearth\'s own '
          'music — the mark by each heard song in the ledger sets it, '
          'and the gold mark gives it back to Hearthside.',
      'The delve\'s own themes below stay as written.',
    ],
  ),
  NewsEntryDef(
    version: '0.74.0',
    title: 'The Full Roster',
    lines: [
      'The ledger\'s delver roster now shows each delver whole: their '
          'sprite in its worn dye, their given name, their worn title, '
          'and how deep they have charted.',
      'Locked delvers keep their mystery.',
    ],
  ),
  NewsEntryDef(
    version: '0.73.0',
    title: 'The Opened Vista',
    lines: [
      'When a run opens a new vista, the summary now says so - one quiet '
          'gold line, same as an earned title.',
      'The colors were always yours the moment you earned them; now the '
          'delve tells you at the moment it happens.',
    ],
  ),
  NewsEntryDef(
    version: '0.72.0',
    title: 'The Given Name',
    lines: [
      'Your delvers are yours to name. Tap a delver\'s name on the '
          'roster and give them your own - it follows them to the run '
          'summary, the ledger, and the Delver\'s Card.',
      'Empty the field to give the true name back. Free, and always '
          'reversible.',
    ],
  ),
  NewsEntryDef(
    version: '0.71.0',
    title: 'The First Words',
    lines: [
      'A delver told us they finished easy mode still wondering what a '
          'delve IS. Fair. Now a brand-new hearth says it plainly: the '
          'delve is the dark below, floor under floor - go down with '
          'your dice, come back with the Ember.',
      'The words show once, before your first run, then step aside '
          'forever. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.70.0',
    title: 'The Pictured Card',
    lines: [
      'The Delver\'s Card now carries your delver - their own sprite, in '
          'the dye they wear. The card you share is your run, told by the '
          'one who walked it.',
      'Cards cut from the Ledger paint the delver as they stand today. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.69.0',
    title: 'The Standing Delver',
    lines: [
      'Your delver now stands on their own summary - in their worn dye, '
          'named with their worn title. A win finds them breathing; a '
          'loss finds them still, but still yours.',
      'The trophy and the flame made way. The run always belonged to the '
          'one who walked it - now the last screen says so. Thank you '
          'for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.68.0',
    title: 'The Earned Name',
    lines: [
      'A run that earns an epithet now says so - one quiet gold line on '
          'the summary, win or loss alike. The title was always yours '
          'the moment you earned it; now the moment speaks.',
      'No buttons, no fanfare - the wardrobe holds the detail, as ever. '
          'Earned by delving, never sold. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.67.0',
    title: 'The Dyed Delver',
    lines: [
      'Dyes are now worn per delver too. Buy a dye once with embers and '
          'any delver may wear it - the Kindler in Emberwash, the Warden '
          'in Frostveil - each keeps their own coat on every screen.',
      'The hearth shows it best: your delvers gather around the fire, '
          'each in the color you chose for them. Pure cosmetics, real '
          'prices up front, as always. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.66.0',
    title: 'The Dressed Delver',
    lines: [
      'Epithets are now worn per delver. Dress the Kindler as the '
          'Unburnt and the Warden as the Thorough - each carries their '
          'own title on the card, the story, and the stone.',
      'A small row of name-chips sits above the epithet shelf once a '
          'second delver joins the hearth. Pick a delver, pick a title. '
          'Earned by delving, never sold. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.65.0',
    title: 'The Charted Depth',
    lines: [
      'The delver picker now charts each character\'s deepest floor '
          'beside their tally - "5 wins - 12 delves - floor 6" - read '
          'straight from the ledger, never estimated.',
      'Older profiles chart what their run history can prove, and '
          'nothing more. A delver with no provable depth shows the '
          'plain tally: no guessed floors, ever.',
    ],
  ),
  NewsEntryDef(
    version: '0.64.0',
    title: 'The Deepshale',
    lines: [
      'A sixth vista, cut from the delve\'s true floor: stand on the '
          'ninth layer - won or lost - and the deep\'s own slate is '
          'yours to wear. The first vista that drains color instead of '
          'raising it.',
      'Like every vista, it is earned by delving and never sold. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.63.0',
    title: 'The Fitted Name',
    lines: [
      'On the narrowest phones the EMBERDELVE wordmark ran off both '
          'edges of the title. It now takes the measure of the screen '
          'it stands on and fits itself exactly.',
      'A small mend, found in our own review plates. Thank you for '
          'playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.62.0',
    title: 'The Kept Fire',
    lines: [
      'Come back after a week or more away and the hearth says so - one '
          'warm line, the true count of days, nothing owed. The fire '
          'never went out while you were gone.',
      'Nothing was counted against you and nothing decayed. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.61.0',
    title: 'The Deepest Mark',
    lines: [
      'The summary now says when a run stood deeper than any before it - '
          'one line, win or loss. A fall on your deepest floor yet is '
          'still your deepest floor yet.',
      'Your first run says nothing; a record needs a record to beat. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.60.0',
    title: "The Delver's Tally",
    lines: [
      'The delver picker now states your record with each delver - wins '
          'and delves, the same tally the Ledger keeps. Pick your main '
          'knowing exactly what the two of you have been through.',
      'Fresh delvers show nothing until their first delve; a record is '
          'earned, not printed. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.59.0',
    title: 'The Proven',
    lines: [
      'The Provings finally crown their victor: clear every proving and a '
          'tenth epithet is yours - the Proven, worn under your delver\'s '
          'name like any title earned in the dark.',
      'Earned by delving, never sold, as every epithet before it. Thank '
          'you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.58.0',
    title: 'The Remembered Fights',
    lines: [
      'The Ledger\'s rows now say who the delver WAS that day: runs '
          'remembered with a worn epithet carry it in their line, and the '
          'fights-won count sits beside the date.',
      'Only banked facts, as always - rows from before the fuller record '
          'stay exactly as they were. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.57.0',
    title: 'The Fuller Record',
    lines: [
      'The Ledger remembers more from today onward: every new run banks '
          'its fights won, its floor trace, and the epithet worn - so a '
          'remembered Delver\'s Card carries the full story, grid and all.',
      'Older entries stay exactly as honest as they were: what was never '
          'banked is still omitted, never invented. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.56.0',
    title: 'Card from the Ledger',
    lines: [
      'The Delver\'s Card no longer dies with the summary screen: every '
          'remembered win or loss in the Ledger now carries a share icon, '
          'so last week\'s run can still land in the group chat - '
          'epitaph, Delve Code and all.',
      'The card only states what the Ledger actually banked - nothing is '
          'ever invented to fill a line. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.55.0',
    title: 'The Duskquartz',
    lines: [
      'A fifth vista waits on the shelf: Duskquartz, where quartz veins '
          'catch the last light and the delve keeps its own dusk. It is '
          'the first vista the Provings feed - clear three and it is yours.',
      'Palette only, like every vista - the delve does not grow a byte. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.54.0',
    title: 'The Epitaph',
    lines: [
      'The Delver\'s Card now carries your run\'s story under your name - '
          'who came back up, or what ended the delve and where. The same '
          'honest voice as the summary screen, cut to card size.',
      'The card also stopped breaking on big-text devices - it renders '
          'like the picture it is now. Thank you for playing, and for '
          'every card that lands in a group chat.',
    ],
  ),
  NewsEntryDef(
    version: '0.53.0',
    title: 'The Rumor',
    lines: [
      'Every delve now opens with a named destination: the boon pick tells '
          'you which boss the seed has already chosen to wait at the bottom. '
          'The seed decided it before your first roll - we just stopped '
          'keeping the secret.',
      'Type a seed or paste a Delve Code and the rumor shows before you '
          'commit - so a shared code can promise a foe, not just a number. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.52.0',
    title: "The Tinker's Proving",
    lines: [
      'The tenth proving takes the last empty seat: the Tinker on normal '
          'floors, seed and all, machine-proven winnable like every proving '
          'before it. Steady pips - the plan, not the roll, decides it.',
      'A new epithet waits beside it: the Well-Oiled, worn for winning a '
          'delve as the Tinker. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.51.0',
    title: 'The Obituary',
    lines: [
      'Every finished delve now tells its own story: a short, honest '
          'epitaph on the summary screen - who went down, how far, how '
          'clean, and what ended it. Copy it as plain text and paste it '
          'anywhere.',
      'The Ledger remembers too: lost delves in Recent Delves now name '
          'the foe that ended them. Every word comes from the run itself. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.50.0',
    title: 'The Tinker',
    lines: [
      'A sixth delver joins the hearth: the Tinker never rolls scared and '
          'never rolls wild. Steady dice under Loaded Pips - the best '
          'floors in the roster, traded for the smallest ceiling.',
      'Unlocks for 600 embers. Two new ledger entries wait: Well Oiled, '
          'and Six Ways Down for winning with the whole company. Thank you '
          'for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.49.0',
    title: 'The Shorter Road',
    lines: [
      'A new way to delve: the Short Road runs six floors instead of nine - '
          'a whole delve, elite and hearth and shop and boss, sized for a '
          'shorter sit. Flip the toggle under the difficulty selector.',
      'Rewards run deeper to fit the climb and the heaviest foes are tuned '
          'to match. Delve Codes carry the format, so a shared short delve '
          'is the same short delve. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.48.0',
    title: 'The Iron Between',
    lines: [
      'Elite foes now carry their own battle theme - a harder drum between '
          'the common fights and the crowned deep, so your ears know the '
          'stakes before the first die lands.',
      'It joins the Gramophone as the eighth record: cross blades with an '
          'elite and it is yours to replay at the hearth. Thank you for '
          'playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.47.0',
    title: 'The Answered Blow',
    lines: [
      'Three new foes fight back on their own terms: the Vent Ram winds up '
          'a hit you can break, the Cinder Urchin makes every strike cost '
          'you, and the Magma Lancer examines you on both.',
      'Their badges state the answer plainly - read the intent, pick your '
          'response. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.46.0',
    title: 'The Delvers Before',
    lines: [
      'Six new happenings below - cold camps, cairns, a lantern left '
          'burning - and four new relics left by the delvers who walked '
          'this road ahead of you.',
      'The Codex grows four entries to match. The delve remembers '
          'everyone. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.45.0',
    title: 'The Deeper Song',
    lines: [
      'A new piece of music now takes over past the midpoint of every '
          'delve - the road down has a darker song than the road in.',
      'It joins the Gramophone as the seventh record: descend far enough '
          'and it is yours to replay at the hearth. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.44.0',
    title: 'The Retraced Road',
    lines: [
      'A lost delve now offers one more door: retrace it. Same map, same '
          'offers, same rolls - only your choices change.',
      'The Daily and Weekly stay one shared attempt each, as they should. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.43.0',
    title: 'The Remembered Delves',
    lines: [
      'Every run in the Ledger\'s recent delves now carries its own Delve '
          'Code - tap a row to copy it, and any remembered run can be '
          'shared or replayed, not just the last one.',
      'Runs from before codes existed simply stay quiet rather than offer '
          'a code that would lie. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.42.0',
    title: 'The Gathered Hearth',
    lines: [
      'The title fire now seats every delver you have unlocked - the '
          'whole company idles at the hearth, right where the kindler '
          'always stood.',
      'Nothing to buy, nothing to do: the roster you earned is simply '
          'there each time the game opens. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.41.0',
    title: 'The Ninth Proving',
    lines: [
      'The Provings grow by one: The Full Purse, the Peddler on normal '
          'floors. Lean dice the whole way down; the Kiln Key pays for '
          'the climb.',
      'Every delver now has a seat at the table - nine exact delves, '
          'each proven winnable before it earned a name. The mark is '
          'still the whole prize. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.40.0',
    title: 'The Peddler',
    lines: [
      'A fifth delver waits at the fire. The Peddler carries a lean pouch '
          '- two Ember Dice and a Flint Shard - but holds the Kiln Key, '
          'so every won fight pays well. The shops do the forging.',
      'A new signature tool, the Coin Hook, and three new ledger marks '
          'ride along. The Peddler unlocks with banked embers, like every '
          'delver before.',
      'The old roster marks keep their words honest: Full Hearth and Four '
          'Ways Down still count four, exactly as earned. Thank you for '
          'playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.39.0',
    title: 'The Waymarks',
    lines: [
      'The end of a run now names what is within reach: up to two ledger '
          'marks you have already started, with the true count beside each.',
      'Only real progress is shown - a goal you have not begun stays '
          'quiet, and a mark grants nothing but its name.',
      'The same counts have always lived in the Ledger. Now the summary '
          'points the way. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.38.0',
    title: 'The Provings',
    lines: [
      'Eight named delves now wait on the title screen - each one exact, '
          'same floors and same rolls for everyone, and every one of them '
          'proven winnable before it earned a name.',
      'Take them in any order. Clearing one marks it on the list; the mark '
          'is the whole prize. Each carries its Delve Code, so a proving '
          'is also something you can hand to a friend.',
      'Nothing rotates and nothing is timed. The list will still be there '
          'tomorrow. Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.37.0',
    title: 'The Delve Codes',
    lines: [
      'Every finished run now leaves a Delve Code - one short code that '
          'packs the seed, the delver, the difficulty, the rung. '
          'A friend plays YOUR run, not one like it.',
      'Tap it on the summary to copy; paste any code into "Delve a seed" '
          'on the title screen. It rides your shared cards too.',
      'Codes work anywhere text does - no account, no internet needed. '
          'Thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.36.0',
    title: 'The Epithets',
    lines: [
      'Delvers now wear their deeds. Eight epithets - the Unburnt, '
          'the Bossbane, the Highborne and more - earned by delving, '
          'worn under your name.',
      'Pick one on the character screen, below your dyes and vistas. '
          'It rides your shared cards too: "The Kindler, the Unburnt".',
      'Every title is earned at the fire, never sold. Thank you for '
          'playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.35.0',
    title: 'The Vistas',
    lines: [
      'The delve can wear new light. Vistas - moonveil, verdigris, '
          'bloodstone - re-tint every floor, earned by the delving itself.',
      'Find them beside your dyes on the character screen. Nothing to buy; '
          'win a delve and the first one is already yours.',
      'Asked for by a delver by the fire - thank you for playing.',
    ],
  ),
  NewsEntryDef(
    version: '0.34.0',
    title: "The Delver's Card",
    lines: [
      'Won a delve worth bragging about? Lost one worth laughing about? '
          'The summary can now press it into a little card - share it '
          'wherever you like, or keep it to yourself.',
      'Every card carries its seed, so a friend can walk the same dark '
          'you did.',
      'Settled by the fire: a quiet way to redeem unlock codes lives in '
          'Settings now.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.33.0',
    title: 'The Gramophone',
    lines: [
      'The Ledger has grown a gramophone. Every tune the delve has played '
          'you is kept there now - tap a heard track to let it play by '
          'the fire.',
      'Six songs wait in the dark. You will meet the rest the way you '
          'meet everything down there: by delving.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.32.0',
    title: 'The Open Rung',
    lines: [
      'Forge-keepers: win at your highest ascension and the summary now '
          'names the rung your victory has opened - the ladder tells you '
          'plainly how far you have climbed.',
      'Nothing is taken if you rest a while; every rung you open stands '
          'open for good.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.31.0',
    title: 'The Growing Codex',
    lines: [
      'When a run adds a new tale to your record, the summary now says '
          'where those tales live: the Codex, and how much of it you have '
          'unsealed so far.',
      'Every foe met and felled is already yours - the Ledger holds the '
          'door open whenever you want to read.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.30.0',
    title: "The Delver's Primer",
    lines: [
      'New by the fire? The map now tells you what a delve is the first '
          'time you see one: descend, fight, and bank every ember you '
          'carry home.',
      'Fall and the fire still keeps half your pouch warm - no delve is '
          'ever for nothing.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.29.0',
    title: 'The Next Delve',
    lines: [
      'Tame the easy delve and the summary now offers the next one: '
          'the same halls on Normal, with sharper teeth and a fuller '
          'ember pouch.',
      'One tap and your next run starts on Normal. It is an invitation, '
          'not a demand - Easy remains yours forever.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.28.0',
    title: 'The Shifting Strata',
    lines: [
      'The delve now looks as deep as it feels. Each layer you descend, '
          'the world itself shifts - warm hearthlight at the surface, '
          'ash-blue in the middle depths, wyrm-violet where the boss waits.',
      'Same rooms, same fights, same odds - only the light changes. '
          'Climb back to the surface and the warmth returns.',
      'Thank you for delving with us. See you by the fire.',
    ],
  ),
  NewsEntryDef(
    version: '0.27.0',
    title: 'The Delver\'s Wardrobe',
    lines: [
      'The first thing a player ever asked us for: make the delver yours. '
          'The Wardrobe opens on the Choose-a-delver screen with eight '
          'dyes - ember-warm, frost-pale, moss-green and more. Your dye '
          'follows you everywhere: the title fire, the map, the fight.',
      'Dyes are bought with embers you earn by delving, prices up front, '
          'same as hearth colors and dice skins. Pure cosmetics - the '
          'delve itself never changes.',
      'Asked for by our very first outside reviewer. Keep telling us what '
          'you want; it clearly works.',
    ],
  ),
  NewsEntryDef(
    version: '0.26.0',
    title: 'The Guided Delve',
    lines: [
      'New delvers asked how the delve actually works - fair. The first '
          'fight now walks you through it on the real screen: your dice, '
          'the enemy\'s telegraphed move, attack and block, the risky '
          'reroll. Five short steps, skippable any time.',
      'Everyone sees the tour once - even long-time delvers, since it '
          'points at things the old cards only described. Replay it '
          'whenever you like from Settings.',
      'Thanks for every message about what was confusing. This update '
          'exists because you sent them.',
    ],
  ),
  NewsEntryDef(
    version: '0.25.0',
    title: 'The Unquiet Deep',
    lines: [
      'The deep is unsettled after the fall of the Hearthless King. Six new '
          'rooms wait on the paths between fights - a toppled throne, a '
          'soot choir, a hermit who trades in dice, and more. The event '
          'deck grows from 33 to 39, so an evening of runs repeats itself '
          'even less.',
      'Four new relics join the pool: the Drowned Bell, the Ashglass '
          'Prism, the Wyrmscale Cloak, and the Choir Censer. Each one '
          'combines two familiar effects, and each has its story in the '
          'Codex.',
      'Event outcomes that change nothing now say so - a bathe at full '
          'health tells you plainly that nothing changed.',
    ],
  ),
  NewsEntryDef(
    version: '0.24.0',
    title: 'The Carried Ember',
    lines: [
      'Your progress now travels as one line of text. Settings has a new '
          'panel: Carry Your Ember. Copy a save code on this device, paste '
          'it on another, and the two ledgers merge - counters keep the '
          'higher mark, everything earned anywhere stays earned.',
      'Merging never takes anything away. Pasting an old code after weeks '
          'of play loses nothing; the code simply adds what the other '
          'device knew.',
      'The Ember Forge purchase moves with your Play account rather than '
          'the code, so a shared code shares progress, never the purchase.',
    ],
  ),
  NewsEntryDef(
    version: '0.23.0',
    title: 'The Deep Hum',
    lines: [
      'The delve has found its voice. The ember bed that crackles under '
          'the title screen now follows you onto the map - a whisper on '
          'the first floors, a low hum by the time the boss door is in '
          'sight.',
      'It never restarts or hiccups as you step deeper; the loop simply '
          'swells. Your music volume slider governs it, and silence still '
          'means silence.',
      'Nothing else changed: no new files, no new permissions, and the '
          'download is exactly the size it was.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.22.0',
    title: 'The Crowned Deep',
    lines: [
      'Two new bosses hold the deep: the Slag Regent, who guards in '
          'perfect silence twice and then ends the audience, and the '
          'Hearthless King, who keeps the only time left to him - strike, '
          'guard, strike, guard.',
      'The road down changes too: the Ashglass Sentinel and the Coal-Seam '
          'Wyrm rehearse the kings\' rhythms at a survivable scale, two '
          'new events pay court on the causeway, and two new relics - the '
          'Siege Hook and the King\'s Ransom - join the pool.',
      'Eight bosses now share the throne-rota, so the daily trial can '
          'crown a king. Every addition sits inside the fairness bands we '
          'measure - nothing got quietly harder.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.21.0',
    title: 'The Watchtower',
    lines: [
      'The game can now tell you when a newer release is out. A "Check" '
          'button lives in Settings — one tap, one plain answer, and a '
          'copyable link to the releases page. Nothing downloads itself.',
      'Prefer it automatic? Turn on "Check once at launch" (it starts '
          'OFF). If a newer release exists you get one quiet line on the '
          'title screen; dismiss it once and it stays gone.',
      'No nags, no badges, and zero network calls unless you ask - '
          'our tests prove the off switch means off.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.20.0',
    title: 'The Living Ladder',
    lines: [
      'The Ascension ladder has been rebuilt. The old math quietly made '
          'the top rungs unwinnable - we measured it, and no build could '
          'climb past rung 12. That broke a promise, so we fixed the math.',
      'Rungs now ramp the way HARD does: the first floors stay a fair '
          'door at every rung, and the real bite waits deep in the delve. '
          'Every rung also toughens enemies a touch, so each step up is '
          'a real step.',
      'All twenty rungs are now provably winnable - our test suite '
          'refuses to build the game if the ladder ever goes dead again.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.19.0',
    title: 'The Spoken Flame',
    lines: [
      'Emberdelve now speaks. With TalkBack on, every button, die, toggle '
          'and map medallion announces itself — kind, floor, and whether '
          'you can reach it.',
      'Phase changes are called out ("The delve map", "Combat: Ash Thrall '
          'with 14 HP"), and every toast — heals, forges, surges — is '
          'spoken the moment it appears.',
      'A new automated gate walks the whole game and fails our build if '
          'any control ever goes silent again.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.18.0',
    title: 'The Trimmed Wick',
    lines: [
      'The download just lost weight: the arm64 install is about 5 MB '
          'smaller, with not one thing removed from the game.',
      'We re-encoded the four music loops at a leaner quality tuned for '
          'phones — loop points are sample-exact, so nothing skips.',
      'The engine also stopped packing debug symbols it never needed. '
          'Same game, same saves, lighter lantern to carry.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.17.0',
    title: 'The Even Scales',
    lines: [
      'A balance pass, measured, not guessed: we ran every character '
          'through hundreds of scripted delves and evened the odds.',
      'The Warden was quietly winning far too often — she now starts '
          'with a Slate Chip (forge it into her old Ward Iron) and 32 HP.',
      'The Gambler and the Ascetic each breathe a little easier: +1 and '
          '+4 max HP. Old saves are untouched — this only changes new runs.',
      'Thank you for delving with us.',
    ],
  ),
  NewsEntryDef(
    version: '0.16.0',
    title: 'The Still Flame',
    lines: [
      'New in Settings: Reduce motion. No screen shake, no drifting '
          'embers, damage numbers hold still — for anyone the moving '
          'image treats unkindly.',
      'It follows your system accessibility setting by default; one tap '
          'overrides it either way.',
    ],
  ),
  NewsEntryDef(
    version: '0.15.0',
    title: 'The Hearthside Post',
    lines: [
      'This note is new. When the delve changes, a post waits here by '
          'the hearth — read it once and it steps aside.',
      'Every past post keeps in Settings, if you ever want to reread one.',
    ],
  ),
  NewsEntryDef(
    version: '0.14.0',
    title: 'The Lighter Lantern',
    lines: [
      'The install now travels lighter — a smaller download, built for '
          'your device.',
      'The delve itself is unchanged: same maps, same dice, same dark.',
    ],
  ),
  NewsEntryDef(
    version: '0.13.0',
    title: "The Delver's Rank",
    lines: [
      'The Ledger now keeps your Rank — nine tiers from Ashfoot to '
          'Deepfire Sovereign, earned mark by mark from what you have '
          'actually done.',
      'Marks only accumulate. No rank is ever taken away.',
    ],
  ),
];

/// The entry for [version], or null when that release shipped no note.
NewsEntryDef? newsFor(String version) {
  for (final e in newsEntries) {
    if (e.version == version) return e;
  }
  return null;
}

/// Compare two dotted numeric versions ('' sorts before everything).
/// Returns negative when a sorts before b, 0 when equal, positive when
/// a sorts after b. Non-numeric segments
/// count as 0 — this only ever sees our own version names.
int compareVersions(String a, String b) {
  final pa = a.split('.'), pb = b.split('.');
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final va = i < pa.length ? (int.tryParse(pa[i]) ?? 0) : 0;
    final vb = i < pb.length ? (int.tryParse(pb[i]) ?? 0) : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}
