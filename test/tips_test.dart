// test/tips_test.dart — v0.10.0 "The First Delve": staged contextual tips.
//
// Covers the pure TipDirector rules (one at a time, once ever, recurrence
// after suppression, all four triggers), MetaState persistence + veteran
// migration, cloud-merge union, and a widget smoke test proving the old
// 4-card wall no longer auto-runs while the roll_spend tip does.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  group('TipDirector', () {
    test('map arrival fires whats_a_delve once ever', () {
      final d = TipDirector(<String>{});
      expect(d.onMapArrival(), ContextTips.whatsADelve);
      expect(d.active, ContextTips.whatsADelve);
      d.dismiss();
      expect(d.seen, contains(ContextTips.whatsADelve));
      // Every later map visit is a no-op.
      expect(d.onMapArrival(), isNull);
      expect(d.active, isNull);
    });

    test('map arrival while another tip is up is suppressed, not consumed', () {
      final d = TipDirector(<String>{});
      d.onFightStart(); // roll_spend active
      expect(d.onMapArrival(), isNull);
      expect(d.seen, isNot(contains(ContextTips.whatsADelve)));
      d.dismiss();
      // Recurs at the next map arrival.
      expect(d.onMapArrival(), ContextTips.whatsADelve);
    });

    test('fight start fires roll_spend once ever', () {
      final d = TipDirector(<String>{});
      expect(d.onFightStart(), ContextTips.rollSpend);
      expect(d.active, ContextTips.rollSpend);
      expect(d.dismiss(), isFalse); // not the last tip
      expect(d.seen, contains(ContextTips.rollSpend));
      // Never again — not even after dismissal.
      expect(d.onFightStart(), isNull);
      expect(d.active, isNull);
    });

    test('one tip at a time: a suppressed trigger is NOT marked seen', () {
      final d = TipDirector(<String>{});
      d.onFightStart(); // roll_spend active
      // A combo fires while the card is up — suppressed, not consumed.
      expect(
        d.onEvents([
          {'type': 'combo_pair', 'bonus': 2},
        ]),
        isNull,
      );
      expect(d.seen, isNot(contains(ContextTips.combosPay)));
      d.dismiss();
      // The trigger recurs at the next natural moment and fires then.
      expect(
        d.onEvents([
          {'type': 'combo_straight'},
        ]),
        ContextTips.combosPay,
      );
    });

    test('enemy action events fire intent_fair', () {
      final d = TipDirector(<String>{});
      expect(
        d.onEvents([
          {'type': 'turn_started'},
          {'type': 'enemy_attacked', 'amount': 3},
        ]),
        ContextTips.intentFair,
      );
    });

    test('big telegraphed attack fires block_fades; small ones do not', () {
      final d = TipDirector(<String>{});
      expect(d.onIntent({'kind': 'attack', 'amount': 3}), isNull);
      expect(d.onIntent({'kind': 'block', 'amount': 9}), isNull);
      expect(
        d.onIntent({'kind': 'attack', 'amount': bigHitThreshold}),
        ContextTips.blockFades,
      );
      d.dismiss();
      expect(d.onIntent({'kind': 'attack_block', 'amount': 7}), isNull);
    });

    test('attack_block intents count for block_fades', () {
      final d = TipDirector(<String>{});
      expect(
        d.onIntent({'kind': 'attack_block', 'amount': 5, 'block': 2}),
        ContextTips.blockFades,
      );
    });

    test('unknown events and malformed intents are ignored', () {
      final d = TipDirector(<String>{});
      expect(
        d.onEvents([
          {'type': 'gold_gained', 'amount': 5},
          {'type': 'dice_rolled'},
        ]),
        isNull,
      );
      expect(d.onIntent({'kind': 'attack'}), isNull); // no amount
      expect(d.onIntent({'amount': 9}), isNull); // no kind
    });

    test('dismissing the last unseen tip reports allSeen', () {
      final d = TipDirector({
        ContextTips.whatsADelve,
        ContextTips.rollSpend,
        ContextTips.intentFair,
        ContextTips.combosPay,
        ContextTips.firstAnvil, // v0.139.0 joined the deck
        ContextTips.sharedDelve, // v0.153.0 joined the deck
      });
      expect(d.onIntent({'kind': 'attack', 'amount': 6}), isNotNull);
      expect(d.dismiss(), isTrue);
      expect(d.allSeen, isTrue);
    });

    test('dismiss with nothing active is a no-op', () {
      final d = TipDirector(<String>{});
      expect(d.dismiss(), isFalse);
      expect(d.seen, isEmpty);
    });
  });

  group('MetaState persistence', () {
    test('tipsSeen round-trips through json, sorted', () {
      final m = MetaState(
        tipsSeen: {ContextTips.combosPay, ContextTips.rollSpend},
      );
      final j = m.toJson();
      expect(j['tipsSeen'], ['combos_pay', 'roll_spend']);
      final back = MetaState.fromJson(Map<String, dynamic>.from(j));
      expect(back.tipsSeen, m.tipsSeen);
    });

    test('empty tipsSeen writes no key and reads back empty', () {
      final j = MetaState().toJson();
      expect(j.containsKey('tipsSeen'), isFalse);
      expect(
        MetaState.fromJson(Map<String, dynamic>.from(j)).tipsSeen,
        isEmpty,
      );
    });

    test('veteran migration: tutorialSeen without tipsSeen seeds all', () {
      final m = MetaState.fromJson({'tutorialSeen': true});
      expect(m.tipsSeen, ContextTips.all.toSet());
      // A fresh profile stays empty.
      expect(MetaState.fromJson({}).tipsSeen, isEmpty);
      // An explicit tipsSeen key wins over the veteran seed.
      final n = MetaState.fromJson({
        'tutorialSeen': true,
        'tipsSeen': ['roll_spend'],
      });
      expect(n.tipsSeen, {ContextTips.rollSpend});
    });

    test('cloud merge unions tipsSeen', () {
      final local = MetaState(tipsSeen: {ContextTips.rollSpend});
      final cloud = MetaState(tipsSeen: {ContextTips.combosPay});
      final merged = mergeMetaStates(local, cloud);
      expect(merged.tipsSeen, {ContextTips.rollSpend, ContextTips.combosPay});
    });
  });

  group('GameController', () {
    test('dismissTip persists via the shared set and sets the legacy flag', () {
      final c = GameController();
      c.meta.tipsSeen.addAll(
        ContextTips.all.where((t) => t != ContextTips.rollSpend),
      );
      expect(c.tipDirector.onFightStart(), ContextTips.rollSpend);
      c.dismissTip();
      // The director's set IS meta.tipsSeen — one source of truth.
      expect(c.meta.tipsSeen, ContextTips.all.toSet());
      // Last tip dismissed ⇒ older builds must not replay their wall.
      expect(c.meta.tutorialSeen, isTrue);
    });
  });

  testWidgets(
    'every tip card fits the smallest supported screen at 1.3x text',
    (tester) async {
      // DEMAND overflow sweep: 320x568 at 1.3x — a RenderFlex overflow throws
      // in tests, so pumping each card here IS the assertion.
      tester.view.physicalSize =
          const Size(320, 568) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      final c = GameController();
      c.meta.tourSeenVersion = tourVersion; // tips-in-isolation (see above)
      c.tour = TourDirector(seenVersion: tourVersion);
      Widget app() => MaterialApp(
        theme: buildEmberTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: GameRoot(c),
      );
      await tester.pumpWidget(app());
      c.startRun(character: 'kindler', seed: 1);
      await pumpFor(tester, 700);
      final map = c.state!['map'] as Map;
      final edges = (map['edges'] as Map).cast<String, List>();
      var guard = 0;
      while (c.phase == 'map' && guard++ < 10) {
        final position = (c.state!['map'] as Map)['position'] as int;
        final next = (edges['$position'] as List).cast<int>().first;
        c.apply({'type': 'choose_node', 'node': next});
        await pumpFor(tester, 700);
        if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
        if (c.phase == 'rest') c.apply({'type': 'rest'});
        if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
        if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
        await pumpFor(tester, 700);
      }
      if (c.phase != 'player_turn') return;
      await pumpFor(tester, 2200);

      // Direct field pokes don't notify, and the combat screen is scope-cached
      // (game_root's _scoped) — but its build reads MediaQuery.sizeOf, so a
      // 1-px height jiggle forces the rebuild. Both heights stay "short".
      var h = 568.0;
      for (final id in ContextTips.all) {
        c.tipDirector.active = id;
        h = h == 568.0 ? 567.0 : 568.0;
        tester.view.physicalSize = Size(320, h) * tester.view.devicePixelRatio;
        await pumpFor(tester, 300);
        expect(find.byKey(Key('tip-$id')), findsOneWidget);
        c.tipDirector.active = null;
      }
      await pumpFor(tester, 800); // drain animations before teardown
    },
  );

  testWidgets('first fight: roll_spend tip shows, the old wall does not', (
    tester,
  ) async {
    final c = GameController(); // fresh profile — nothing seen
    // Tips-in-isolation: stamp the Guided Delve tour as seen so it doesn't
    // (correctly) suppress the tip under test.
    c.meta.tourSeenVersion = tourVersion;
    c.tour = TourDirector(seenVersion: tourVersion);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 700);

    // v0.30.0: first contact with the map fires whats_a_delve — dismiss it
    // the way a player would (tap anywhere) before walking to the fight.
    expect(find.byKey(const Key('tip-whats_a_delve')), findsOneWidget);
    expect(find.text('THIS IS A DELVE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tip-card')));
    await pumpFor(tester, 400);
    expect(find.byKey(const Key('tip-card')), findsNothing);
    expect(c.meta.tipsSeen, contains(ContextTips.whatsADelve));

    // Walk to the first fight (seed 1 reaches one; same walk as widget_test).
    final map = c.state!['map'] as Map;
    final edges = (map['edges'] as Map).cast<String, List>();
    var guard = 0;
    while (c.phase == 'map' && guard++ < 10) {
      final position = (c.state!['map'] as Map)['position'] as int;
      final next = (edges['$position'] as List).cast<int>().first;
      c.apply({'type': 'choose_node', 'node': next});
      await pumpFor(tester, 700);
      if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
      if (c.phase == 'rest') c.apply({'type': 'rest'});
      if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
      if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
      await pumpFor(tester, 700);
    }
    if (c.phase != 'player_turn') return; // no early fight on this walk; fine

    await pumpFor(tester, 2200); // outlast a possible name-plate splash

    // The staged tip is up; the 4-card wall's paging footer is not.
    expect(find.byKey(const Key('tip-card')), findsOneWidget);
    expect(find.text('ROLL, THEN SPEND'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1 / \d')), findsNothing);

    // Tap-anywhere dismisses, persists, and never returns.
    await tester.tap(find.byKey(const Key('tip-card')));
    await pumpFor(tester, 400);
    expect(find.byKey(const Key('tip-card')), findsNothing);
    expect(c.meta.tipsSeen, contains(ContextTips.rollSpend));
    expect(c.tipDirector.onFightStart(), isNull);
    await pumpFor(tester, 800); // drain animations before teardown
  });
}
