// test/vistas_test.dart — v0.35.0 The Vistas charter pins.
//
// 1. Identity pin: emberlight at depth 0 = null grade + transparent wash
//    (byte-identical rendering to every pre-vista build).
// 2. Derived-unlock truth table vs the pure resolver AND the controller gate.
// 3. Selection: persists via meta JSON round-trip, rejects locked/unknown ids,
//    cloud merge keeps the fresher side.
// 4. Picker: locked card shows the milestone line + lock, tap does nothing;
//    unlocked tap selects; chosen card marked CHOSEN.
// 5. Ethics sweep on all player-facing vista copy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('identity pin', () {
    test('emberlight at surface is a no-op (grade null, wash transparent)', () {
      expect(Art.backgroundGrade(0, defaultVista), isNull);
      expect(Art.backgroundWash(0, defaultVista).a, 0);
    });

    test('strata grade still applies under emberlight (depth unchanged)', () {
      // The composed grade at depth>0 with the identity vista must be
      // exactly the old strata grade.
      final composed = Art.backgroundGrade(0.7, defaultVista);
      final strata = Art.strataFilter(0.7);
      expect(composed, equals(strata));
      expect(
        Art.backgroundWash(0.7, defaultVista),
        equals(Art.strataWash(0.7)),
      );
    });

    test('a non-default vista grades even at the surface', () {
      expect(Art.backgroundGrade(0, 'moonveil'), isNotNull);
      expect(Art.backgroundWash(0, 'moonveil').a, greaterThan(0));
    });

    test('unknown vista id degrades to identity, never throws', () {
      expect(Art.backgroundGrade(0, 'nonsense'), isNull);
      expect(Art.backgroundWash(0, 'nonsense').a, 0);
    });
  });

  group('derived unlocks', () {
    test('resolver truth table', () {
      // Fresh profile: only emberlight.
      for (final id in vistasOrder) {
        expect(
          vistaUnlockedFor(id, runsWon: 0, distinctFelled: 0, hardWins: 0),
          id == 'emberlight',
          reason: id,
        );
      }
      expect(
        vistaUnlockedFor('moonveil',
            runsWon: 1, distinctFelled: 0, hardWins: 0),
        isTrue,
      );
      expect(
        vistaUnlockedFor('verdigris',
            runsWon: 0, distinctFelled: 15, hardWins: 0),
        isTrue,
      );
      expect(
        vistaUnlockedFor('verdigris',
            runsWon: 9, distinctFelled: 14, hardWins: 9),
        isFalse,
      );
      expect(
        vistaUnlockedFor('bloodstone',
            runsWon: 5, distinctFelled: 30, hardWins: 0),
        isFalse,
      );
      expect(
        vistaUnlockedFor('bloodstone',
            runsWon: 0, distinctFelled: 0, hardWins: 1),
        isTrue,
      );
      expect(
        vistaUnlockedFor('nonsense',
            runsWon: 99, distinctFelled: 99, hardWins: 99),
        isFalse,
      );
    });

    test('controller gate reads real meta counters', () {
      final c = GameController();
      expect(c.vistaUnlocked('emberlight'), isTrue);
      expect(c.vistaUnlocked('moonveil'), isFalse);
      c.meta.runsWon = 1;
      expect(c.vistaUnlocked('moonveil'), isTrue);
      c.meta.hardWins = 1;
      expect(c.vistaUnlocked('bloodstone'), isTrue);
      for (var i = 0; i < 15; i++) {
        c.meta.enemyFelled['enemy_$i'] = 1;
      }
      expect(c.vistaUnlocked('verdigris'), isTrue);
    });
  });

  group('selection', () {
    test('selectVista rejects locked and unknown, accepts earned', () {
      final c = GameController();
      c.selectVista('moonveil'); // locked
      expect(c.meta.selectedVista, defaultVista);
      c.selectVista('nonsense');
      expect(c.meta.selectedVista, defaultVista);
      c.meta.runsWon = 1;
      c.selectVista('moonveil');
      expect(c.meta.selectedVista, 'moonveil');
    });

    test('JSON round-trip: default is compact, choice survives', () {
      final m = MetaState();
      expect(m.toJson().containsKey('selectedVista'), isFalse);
      m.selectedVista = 'verdigris';
      final back = MetaState.fromJson(m.toJson());
      expect(back.selectedVista, 'verdigris');
      // A stale/unknown persisted id must degrade to the default.
      final j = m.toJson();
      j['selectedVista'] = 'retired_vista';
      expect(MetaState.fromJson(j).selectedVista, defaultVista);
    });

    test('cloud merge keeps the fresher side', () {
      final local = MetaState()
        ..runsPlayed = 5
        ..selectedVista = 'moonveil';
      final cloud = MetaState()
        ..runsPlayed = 2
        ..selectedVista = 'bloodstone';
      expect(mergeMetaStates(local, cloud).selectedVista, 'moonveil');
      expect(mergeMetaStates(cloud, local).selectedVista, 'moonveil');
    });
  });

  group('picker', () {
    Future<GameController> pumpCharacterScreen(WidgetTester tester) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
      );
      await pumpFor(tester, 300);
      return c;
    }

    testWidgets('locked vista shows milestone, tap does nothing',
        (tester) async {
      final c = await pumpCharacterScreen(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('vista-moonveil')),
        400,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('vista-moonveil')));
      await pumpFor(tester, 200);
      expect(find.text('Win a delve.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vista-moonveil')));
      await pumpFor(tester, 200);
      expect(c.meta.selectedVista, defaultVista);
    });

    testWidgets('earned vista selects on tap and reads CHOSEN',
        (tester) async {
      final c = GameController();
      c.meta.runsWon = 1; // earned before the screen builds
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
      );
      await pumpFor(tester, 300);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('vista-moonveil')),
        400,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('vista-moonveil')));
      await pumpFor(tester, 200);
      await tester.tap(find.byKey(const ValueKey('vista-moonveil')));
      await pumpFor(tester, 200);
      expect(c.meta.selectedVista, 'moonveil');
      // The moonveil card (on screen) now carries the marker.
      expect(find.text('CHOSEN'), findsOneWidget);
    });
  });

  group('ethics', () {
    test('vista copy carries no pressure language', () {
      const banned = [
        'streak', 'expire', 'hurry', 'miss out', 'last chance',
        'beat me', 'bet you', 'only today', "can't", 'loser',
      ];
      for (final v in vistas.values) {
        final copy = '${v.name} ${v.text} ${v.unlockLine}'.toLowerCase();
        for (final b in banned) {
          expect(copy.contains(b), isFalse, reason: '${v.id}: "$b"');
        }
      }
    });
  });
}
