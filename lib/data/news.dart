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
const String currentAppVersion = '0.30.0';

/// Newest first. Backfilled to v0.13.0 — older releases predate the Post.
const List<NewsEntryDef> newsEntries = [
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
