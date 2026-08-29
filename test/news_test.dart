// test/news_test.dart — The Hearthside Post, headless half (v0.15.0).
//
//   1. currentAppVersion is pinned to pubspec.yaml's version name — the
//      binary can never claim to be a release it is not.
//   2. Every release we ship has a note for the panel to show (newsFor
//      finds an entry for currentAppVersion), entries stay newest-first,
//      and the copy honors the §Ethics banned-word list.
//   3. compareVersions orders dotted versions numerically ('' first).
//   4. Meta round-trips lastSeenNewsVersion; cloud merge keeps the LARGER
//      version from either side so a merge never re-shows old news.
//   5. Boot stamps a brand-new profile silently (no note on fresh install)
//      but leaves a veteran save untouched (the note shows after updates).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('currentAppVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final name = RegExp(
      r'^version:\s*([0-9.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(currentAppVersion, name);
  });

  test('the shipping release has a note; entries are newest-first', () {
    expect(newsFor(currentAppVersion), isNotNull);
    for (var i = 1; i < newsEntries.length; i++) {
      expect(
        compareVersions(newsEntries[i - 1].version, newsEntries[i].version),
        greaterThan(0),
        reason: 'newsEntries must stay newest-first',
      );
    }
    expect(newsFor('0.0.1'), isNull);
  });

  test('news copy holds the ethics line', () {
    const banned = [
      'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
      'bet you', 'only today', "can't", 'loser', // §Ethics
    ];
    for (final e in newsEntries) {
      expect(e.lines.length, inInclusiveRange(2, 4));
      final all = ('${e.title} ${e.lines.join(' ')}').toLowerCase();
      for (final word in banned) {
        expect(all.contains(word), isFalse, reason: '"$word" in v${e.version}');
      }
    }
  });

  test('compareVersions orders numerically, empty first', () {
    expect(compareVersions('0.15.0', '0.14.0'), greaterThan(0));
    expect(
      compareVersions('0.9.0', '0.15.0'),
      lessThan(0),
    ); // not lexicographic
    expect(compareVersions('0.15.0', '0.15.0'), 0);
    expect(compareVersions('', '0.13.0'), lessThan(0));
    expect(compareVersions('1.0', '1.0.0'), 0);
  });

  test('meta round-trips lastSeenNewsVersion (absent => never seen)', () {
    final m = MetaState()..lastSeenNewsVersion = '0.15.0';
    final back = MetaState.fromJson(m.toJson().cast<String, dynamic>());
    expect(back.lastSeenNewsVersion, '0.15.0');
    expect(MetaState.fromJson(const {}).lastSeenNewsVersion, '');
  });

  test('cloud merge keeps the larger seen-version from either side', () {
    final a = MetaState()..lastSeenNewsVersion = '0.13.0';
    final b = MetaState()..lastSeenNewsVersion = '0.15.0';
    expect(mergeMetaStates(a, b).lastSeenNewsVersion, '0.15.0');
    expect(mergeMetaStates(b, a).lastSeenNewsVersion, '0.15.0');
    final blank = MetaState();
    expect(mergeMetaStates(blank, b).lastSeenNewsVersion, '0.15.0');
    expect(mergeMetaStates(b, blank).lastSeenNewsVersion, '0.15.0');
  });

  test(
    'boot stamps fresh installs silently, leaves veterans unstamped',
    () async {
      final dir = await Directory.systemTemp.createTemp('ed_news_fresh');
      addTearDown(() async {
        MetaStore.dirOverride = null;
        for (var i = 0; i < 10; i++) {
          try {
            await dir.delete(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
      });
      MetaStore.dirOverride = dir.path;

      // Fresh install: no meta file at all -> stamped, no note ever shows.
      final fresh = GameController(saveDirOverride: dir.path);
      await fresh.boot();
      expect(fresh.meta.lastSeenNewsVersion, currentAppVersion);

      // Veteran profile from before v0.15.0: runs played, no field -> stays
      // '' so the title shows the note exactly once.
      await MetaStore.save(MetaState()..runsPlayed = 12);
      final vet = GameController(saveDirOverride: dir.path);
      await vet.boot();
      expect(vet.meta.lastSeenNewsVersion, '');
    },
  );
}
