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
const String currentAppVersion = '0.17.0';

/// Newest first. Backfilled to v0.13.0 — older releases predate the Post.
const List<NewsEntryDef> newsEntries = [
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
