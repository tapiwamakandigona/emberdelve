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
const String currentAppVersion = '0.55.0';

/// Newest first. Backfilled to v0.13.0 — older releases predate the Post.
const List<NewsEntryDef> newsEntries = [
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
