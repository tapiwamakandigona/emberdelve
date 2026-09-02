// test/spoken_badge_test.dart — v0.180.0 "The Spoken Badge"
// (docs/research/r9-first-run-spec.md §3).
//
// Pins:
//   1. Director: each response-puzzle intent kind speaks once ever; plain
//      attack/block never speak; quiet (and NOT consumed) while a tip card is
//      up; never touches `active` or the legacy allSeen contract.
//   2. Persistence: keys ride MetaState.tipsSeen — JSON round-trip and cloud
//      union — and a returning save that has heard them stays silent.
//   3. Widget: a FRESH profile in its first fight, facing a charge, sees the
//      explain call-out unasked, exactly once; the key is stamped; a second
//      charge is silent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:emberdelve/sim/combos.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<bool> walkIntoFight(WidgetTester tester, GameController c) async {
  final map = c.state!['map'] as Map;
  final edges = (map['edges'] as Map).cast<String, List>();
  var guard = 0;
  while (c.phase == 'map' && guard++ < 10) {
    final position = (c.state!['map'] as Map)['position'] as int;
    final next = (edges['$position'] as List).cast<int>().first;
    c.apply({'type': 'choose_node', 'node': next});
    await pumpFor(tester, 500);
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
    await pumpFor(tester, 500);
  }
  return c.phase == 'player_turn';
}

Map<String, Object?> charge() => {
  'kind': 'charge',
  'amount': 34,
  'threshold': 9,
};

void main() {
  group('TipDirector.onIntentDeclared', () {
    test('each puzzle kind speaks once ever; attack/block never do', () {
      final d = TipDirector(<String>{});
      expect(d.onIntentDeclared(charge()), SpokenBadges.charge);
      expect(d.onIntentDeclared(charge()), isNull);
      expect(
        d.onIntentDeclared({'kind': 'counter', 'amount': 3}),
        SpokenBadges.counter,
      );
      expect(d.onIntentDeclared({'kind': 'stagger'}), SpokenBadges.stagger);
      expect(
        d.onIntentDeclared({'kind': 'attack_block', 'amount': 5, 'block': 4}),
        SpokenBadges.attackBlock,
      );
      expect(d.onIntentDeclared({'kind': 'attack', 'amount': 9}), isNull);
      expect(d.onIntentDeclared({'kind': 'block', 'amount': 9}), isNull);
      expect(d.onIntentDeclared({'kind': 'nonsense'}), isNull);
      expect(d.onIntentDeclared({}), isNull);
      expect(d.seen, containsAll(SpokenBadges.all));
      // A call-out is not a card: active is untouched.
      expect(d.active, isNull);
    });

    test('quiet while a tip card is up, and NOT consumed', () {
      final d = TipDirector(<String>{});
      expect(d.onMapArrival(), ContextTips.whatsADelve);
      expect(d.onIntentDeclared(charge()), isNull);
      expect(d.seen, isNot(contains(SpokenBadges.charge)));
      d.dismiss();
      expect(d.onIntentDeclared(charge()), SpokenBadges.charge);
    });

    test('spoken keys do not count toward the card deck allSeen', () {
      final d = TipDirector(<String>{...ContextTips.all});
      expect(d.allSeen, isTrue);
      final d2 = TipDirector(<String>{...SpokenBadges.all});
      expect(d2.allSeen, isFalse);
      expect(ContextTips.all, isNot(contains(SpokenBadges.charge)));
    });
  });

  group('persistence', () {
    test('keys round-trip through MetaState json', () {
      final m = MetaState()..tipsSeen.add(SpokenBadges.charge);
      final back = MetaState.fromJson(m.toJson());
      expect(back.tipsSeen, contains(SpokenBadges.charge));
      expect(TipDirector(back.tipsSeen).onIntentDeclared(charge()), isNull);
    });

    test('cloud merge unions spoken keys', () {
      final a = MetaState()..tipsSeen.add(SpokenBadges.charge);
      final b = MetaState()..tipsSeen.add(SpokenBadges.counter);
      final merged = mergeMetaStates(a, b);
      expect(
        merged.tipsSeen,
        containsAll([SpokenBadges.charge, SpokenBadges.counter]),
      );
    });
  });

  testWidgets('fresh profile: first charge speaks unasked, once', (
    tester,
  ) async {
    final c = GameController(); // brand-new save — nothing seen
    // Isolate from the tour and the tip cards (each is pinned elsewhere).
    c.meta.tourSeenVersion = tourVersion;
    c.tour = TourDirector(seenVersion: tourVersion);
    c.meta.tipsSeen.addAll(ContextTips.all);
    expect(c.meta.tipsSeen, isNot(contains(SpokenBadges.charge)));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 400);
    if (!await walkIntoFight(tester, c)) return; // no early fight; fine
    await pumpFor(tester, 2400); // outlast the name-plate splash
    // Nothing spoke for a plain attack/block opener.
    expect(find.textContaining('NEXT MOVE'), findsNothing);
    expect(find.textContaining('CHARGING'), findsNothing);

    // Re-script the foe as a Vent Ram: it winds up a charge every turn.
    final enemy = c.sim!.enemy!;
    enemy['hp'] = 999;
    enemy['max_hp'] = 999;
    enemy['pattern'] = [charge(), charge()];
    enemy['pattern_index'] = 0;
    c.sim!.player['hp'] = 99;
    c.sim!.player['max_hp'] = 99;

    // Roll, end turn: the enemy acts, then declares the charge — and the
    // screen speaks it with no long-press anywhere.
    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 900);
    await tester.tap(find.text('End turn'));
    await pumpFor(tester, 2600);
    expect((c.sim!.enemy!['intent'] as Map)['kind'], 'charge');
    expect(find.textContaining('CHARGING 34'), findsOneWidget);
    expect(find.textContaining('DEAL 9 TO BREAK'), findsOneWidget);
    expect(c.meta.tipsSeen, contains(SpokenBadges.charge));
    await pumpFor(tester, 2600); // let the call-out fade
    expect(find.textContaining('CHARGING 34'), findsNothing);

    // Same kind declared again: silent forever.
    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 900);
    await tester.tap(find.text('End turn'));
    await pumpFor(tester, 2600);
    expect((c.sim!.enemy!['intent'] as Map)['kind'], 'charge');
    expect(find.textContaining('CHARGING 34'), findsNothing);
    await pumpFor(tester, 800); // drain animations before teardown
  });

  testWidgets('fight start: an opening charge speaks after the stage settles', (
    tester,
  ) async {
    final c = GameController();
    c.meta.tourSeenVersion = tourVersion;
    c.tour = TourDirector(seenVersion: tourVersion);
    c.meta.tipsSeen.addAll(ContextTips.all);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 400);
    // Walk as usual, but the moment a fight is created (before the screen
    // builds) hand the foe an opening charge — as a Vent Ram declares one.
    final map = c.state!['map'] as Map;
    final edges = (map['edges'] as Map).cast<String, List>();
    var guard = 0;
    while (c.phase == 'map' && guard++ < 10) {
      final position = (c.state!['map'] as Map)['position'] as int;
      final next = (edges['$position'] as List).cast<int>().first;
      c.apply({'type': 'choose_node', 'node': next});
      if (c.phase == 'player_turn') c.sim!.enemy!['intent'] = charge();
      await pumpFor(tester, 500);
      if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
      if (c.phase == 'rest') c.apply({'type': 'rest'});
      if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
      if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
      await pumpFor(tester, 500);
    }
    if (c.phase != 'player_turn') return; // no early fight; fine
    await pumpFor(tester, 1500);
    expect(find.textContaining('CHARGING 34'), findsOneWidget);
    expect(c.meta.tipsSeen, contains(SpokenBadges.charge));
    await pumpFor(tester, 3000); // drain the call-out before teardown
  });

  testWidgets('breaking a charge speaks the stagger badge, once', (
    tester,
  ) async {
    final c = GameController();
    c.meta.tourSeenVersion = tourVersion;
    c.tour = TourDirector(seenVersion: tourVersion);
    c.meta.tipsSeen.addAll(ContextTips.all);
    // The charge itself is not under test here — pre-hear it so only the
    // stagger's first contact can speak.
    c.meta.tipsSeen.add(SpokenBadges.charge);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1);
    await pumpFor(tester, 400);
    if (!await walkIntoFight(tester, c)) return; // no early fight; fine
    await pumpFor(tester, 2400);

    // A Vent Ram's wind-up: 34 incoming, break at 9.
    final enemy = c.sim!.enemy!;
    enemy['hp'] = 999;
    enemy['max_hp'] = 999;
    enemy['intent'] = charge();
    enemy['charge_taken'] = 0;
    enemy['block'] = 0; // only unabsorbed dice damage counts toward the break
    c.sim!.player['hp'] = 99;
    c.sim!.player['max_hp'] = 99;
    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 900);
    // Force a pool whose first two faces break the threshold (6 + 5 ≥ 9).
    c.sim!.player['rolled'] = <int>[6, 5, 3];
    c.sim!.player['rolled_max'] = List<bool>.filled(3, false);
    c.sim!.player['combo_bonus'] = detectCombos(<int>[6, 5, 3]).bonus;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    c.notifyListeners();
    await pumpFor(tester, 300);

    await tester.tap(find.byType(DieChip).at(0));
    await pumpFor(tester, 200);
    await tester.tap(find.text('Attack'));
    await pumpFor(tester, 1600);

    await tester.tap(find.byType(DieChip).at(1), warnIfMissed: false);
    await pumpFor(tester, 200);
    await tester.tap(find.text('Attack'));
    await pumpFor(tester, 600);
    expect(find.textContaining('CHARGE BROKEN'), findsOneWidget);
    expect(find.textContaining('STAGGERED'), findsOneWidget);
    expect(c.meta.tipsSeen, contains(SpokenBadges.stagger));
    await pumpFor(tester, 3000); // drain call-outs before teardown
  });
}
