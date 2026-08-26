// test/epithets_test.dart — v0.36.0 The Epithets charter pins.
//
// 1. Data sanity: every epithet reads a LEGAL Ledger stat (achievementStats),
//    ids are coherent, order covers the map exactly.
// 2. Derived unlocks: the controller gate reads real meta counters through
//    the shared statValue resolver — the same honesty contract as the Ledger.
// 3. Selection: '' (none) always legal, locked/unknown rejected, JSON
//    round-trip compact at default, cloud merge keeps the fresher side.
// 4. Picker: locked card shows milestone + lock and tap does nothing;
//    unlocked tap wears the title (WORN); the none card takes it off.
// 5. Card facts: nameLine appends the worn title; bare when none.
// 6. Ethics sweep on all player-facing epithet copy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data sanity', () {
    test('every epithet uses a legal Ledger stat and a coherent id', () {
      expect(epithetsOrder.toSet(), epithets.keys.toSet());
      for (final e in epithets.values) {
        expect(
          achievementStats.contains(e.stat),
          isTrue,
          reason: '${e.id}: unknown stat "${e.stat}"',
        );
        expect(e.target, greaterThanOrEqualTo(1), reason: e.id);
        expect(epithets[e.id]!.id, e.id);
        expect(e.title, isNotEmpty);
        expect(e.unlockLine, isNotEmpty);
      }
      // The default is the ABSENCE of an epithet, never a map entry.
      expect(defaultEpithet, '');
      expect(epithets.containsKey(defaultEpithet), isFalse);
    });
  });

  group('derived unlocks', () {
    test('fresh profile has earned nothing', () {
      final c = GameController();
      for (final id in epithetsOrder) {
        expect(c.epithetUnlocked(id), isFalse, reason: id);
      }
      expect(c.epithetUnlocked('nonsense'), isFalse);
    });

    test('controller gate reads real meta counters', () {
      final c = GameController();
      c.meta.runsWon = 1;
      expect(c.epithetUnlocked('the_delver'), isTrue);
      expect(c.epithetUnlocked('the_thorough'), isFalse);
      c.meta.runsPlayed = 10;
      expect(c.epithetUnlocked('the_thorough'), isTrue);
      c.meta.exactKills = 25;
      expect(c.epithetUnlocked('the_exact'), isTrue);
      c.meta.winsNoRest = 1;
      expect(c.epithetUnlocked('the_unresting'), isTrue);
      c.meta.bossesBeaten.addAll({'b1', 'b2', 'b3'});
      expect(c.epithetUnlocked('the_bossbane'), isTrue);
      c.meta.lifetimeEmbers = 1000;
      expect(c.epithetUnlocked('the_emberled'), isTrue);
      c.meta.hardWins = 1;
      expect(c.epithetUnlocked('the_unburnt'), isTrue);
      c.meta.bestAscension = 5;
      expect(c.epithetUnlocked('the_highborne'), isTrue);
      // v0.52.0: char-scoped epithet reads the same charWins counter the
      // Ledger's Well Oiled entry reads — param plumbing proven here.
      expect(c.epithetUnlocked('the_well_oiled'), isFalse);
      c.meta.charWins['tinker'] = 1;
      expect(c.epithetUnlocked('the_well_oiled'), isTrue);
    });

    test('one short of the milestone stays locked', () {
      final c = GameController();
      c.meta.runsPlayed = 9;
      expect(c.epithetUnlocked('the_thorough'), isFalse);
      c.meta.exactKills = 24;
      expect(c.epithetUnlocked('the_exact'), isFalse);
      c.meta.bestAscension = 4;
      expect(c.epithetUnlocked('the_highborne'), isFalse);
    });
  });

  group('selection', () {
    test(
      'selectEpithet rejects locked and unknown, accepts earned and none',
      () {
        final c = GameController();
        c.selectEpithet('the_delver', forChar: 'kindler'); // locked
        expect(c.meta.epithetFor('kindler'), defaultEpithet);
        c.selectEpithet('nonsense', forChar: 'kindler');
        expect(c.meta.epithetFor('kindler'), defaultEpithet);
        c.meta.runsWon = 1;
        c.selectEpithet('the_delver', forChar: 'kindler');
        expect(c.meta.epithetFor('kindler'), 'the_delver');
        // v0.66.0: the dress is the delver's own — nobody else's changes.
        expect(c.meta.epithetFor('warden'), defaultEpithet);
        // Taking the title off is always legal.
        c.selectEpithet(defaultEpithet, forChar: 'kindler');
        expect(c.meta.epithetFor('kindler'), defaultEpithet);
      },
    );

    test('JSON round-trip: default is compact, choice survives', () {
      final m = MetaState();
      expect(m.toJson().containsKey('selectedEpithet'), isFalse);
      m.selectedEpithet = 'the_exact';
      final back = MetaState.fromJson(m.toJson());
      expect(back.selectedEpithet, 'the_exact');
      // A stale/unknown persisted id must degrade to bare.
      final j = m.toJson();
      j['selectedEpithet'] = 'retired_title';
      expect(MetaState.fromJson(j).selectedEpithet, defaultEpithet);
    });

    test('cloud merge keeps the fresher side', () {
      final local = MetaState()
        ..runsPlayed = 5
        ..selectedEpithet = 'the_delver';
      final cloud = MetaState()
        ..runsPlayed = 2
        ..selectedEpithet = 'the_unburnt';
      expect(mergeMetaStates(local, cloud).selectedEpithet, 'the_delver');
      expect(mergeMetaStates(cloud, local).selectedEpithet, 'the_delver');
    });
  });

  group('picker', () {
    testWidgets('locked epithet shows milestone, tap does nothing', (
      tester,
    ) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
      );
      await pumpFor(tester, 300);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('epithet-the_delver')),
        400,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('epithet-the_delver')),
      );
      await pumpFor(tester, 200);
      expect(find.text('Win a delve.'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('epithet-the_delver')));
      await pumpFor(tester, 200);
      expect(c.meta.selectedEpithet, defaultEpithet);
    });

    testWidgets('earned epithet wears on tap and reads WORN', (tester) async {
      final c = GameController();
      c.meta.runsWon = 1; // earned before the screen builds
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
      );
      await pumpFor(tester, 300);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('epithet-the_delver')),
        400,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('epithet-the_delver')),
      );
      await pumpFor(tester, 200);
      await tester.tap(find.byKey(const ValueKey('epithet-the_delver')));
      await pumpFor(tester, 200);
      // v0.66.0: the tap dresses the delver (kindler is the only one
      // unlocked, so no chip row and the target defaults to them).
      expect(c.meta.epithetFor('kindler'), 'the_delver');
      // The on-screen card now carries the marker.
      expect(find.text('WORN'), findsOneWidget);
    });

    testWidgets('the none card takes the title off', (tester) async {
      final c = GameController();
      c.meta.runsWon = 1;
      c.meta.selectedEpithet = 'the_delver';
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
      );
      await pumpFor(tester, 300);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('epithet-none')),
        400,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('epithet-none')));
      await pumpFor(tester, 200);
      await tester.tap(find.byKey(const ValueKey('epithet-none')));
      await pumpFor(tester, 200);
      expect(c.meta.epithetFor('kindler'), defaultEpithet);
    });
  });

  group('card facts', () {
    test('nameLine appends the worn title, bare when none', () {
      const bare = DelverCardFacts(
        won: true,
        delverName: 'The Kindler',
        difficulty: 'hard',
        ascension: 0,
        traceGridText: '',
        embers: 100,
        fightsWon: 6,
        seed: 1,
      );
      expect(bare.nameLine, 'The Kindler');
      const titled = DelverCardFacts(
        won: true,
        delverName: 'The Kindler',
        epithetTitle: 'the Unburnt',
        difficulty: 'hard',
        ascension: 0,
        traceGridText: '',
        embers: 100,
        fightsWon: 6,
        seed: 1,
      );
      expect(titled.nameLine, 'The Kindler, the Unburnt');
    });
  });

  group('ethics', () {
    test('epithet copy carries no pressure language', () {
      const banned = [
        'streak',
        'expire',
        'hurry',
        'miss out',
        'last chance',
        'beat me',
        'bet you',
        'only today',
        "can't",
        'loser',
      ];
      for (final e in epithets.values) {
        final copy = '${e.title} ${e.unlockLine}'.toLowerCase();
        for (final b in banned) {
          expect(copy.contains(b), isFalse, reason: '${e.id}: "$b"');
        }
      }
    });
  });
}
