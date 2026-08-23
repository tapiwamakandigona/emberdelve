// test/tour_test.dart — v0.8.0 "The Guided Delve": anchored tour director.
//
// Pure-logic contract for TourDirector (order, action gating, info taps,
// skip, soft-lock immunity) plus MetaState.tourSeenVersion persistence and
// cloud-merge max — the "everyone sees v2 once, including veterans" rule.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(Duration(milliseconds: step));
  }
}

/// Walk a fresh run to its first fight (same walk as tips_test).
Future<bool> walkToFight(WidgetTester tester, GameController c) async {
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
  return c.phase == 'player_turn';
}

void main() {
  group('TourDirector', () {
    test('fresh profile runs and starts at the roll beat', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.running, isTrue);
      expect(d.active, TourBeats.roll);
      expect(d.activeIsInfo, isFalse);
    });

    test('current-version profile does not run', () {
      final d = TourDirector(seenVersion: tourVersion);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('veteran of the old wall (version 0) still runs — the point', () {
      // Old saves have tutorialSeen=true but tourSeenVersion=0.
      final d = TourDirector(seenVersion: 0);
      expect(d.running, isTrue);
    });

    test('replay flag runs the tour even when already seen', () {
      final d = TourDirector(seenVersion: tourVersion, replay: true);
      expect(d.running, isTrue);
      expect(d.active, TourBeats.roll);
    });

    test('action beats advance only on their matching moment', () {
      final d = TourDirector(seenVersion: 0);
      // Wrong moments are ignored — no soft-lock, no accidental skip.
      expect(d.onMoment(TourMoment.diePicked), isFalse);
      expect(d.active, TourBeats.roll);
      expect(d.onMoment(TourMoment.rolled), isFalse);
      expect(d.active, TourBeats.pick);
      expect(d.onMoment(TourMoment.diePicked), isFalse);
      expect(d.active, TourBeats.spend);
      expect(d.onMoment(TourMoment.actionSpent), isFalse);
      expect(d.active, TourBeats.intent);
    });

    test('info beats ignore actions and advance on tap', () {
      final d = TourDirector(seenVersion: 0);
      d.onMoment(TourMoment.rolled);
      d.onMoment(TourMoment.diePicked);
      d.onMoment(TourMoment.actionSpent);
      expect(d.active, TourBeats.intent);
      expect(d.activeIsInfo, isTrue);
      // Rolling again during an info beat changes nothing.
      expect(d.onMoment(TourMoment.rolled), isFalse);
      expect(d.active, TourBeats.intent);
      expect(d.advanceInfo(), isFalse);
      expect(d.active, TourBeats.reroll);
      // Last beat: finishing returns true so the caller stamps + persists.
      expect(d.advanceInfo(), isTrue);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('advanceInfo is a no-op on action beats', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.advanceInfo(), isFalse);
      expect(d.active, TourBeats.roll);
    });

    test('skip ends the tour from any beat and reports completion', () {
      final d = TourDirector(seenVersion: 0);
      d.onMoment(TourMoment.rolled);
      expect(d.skip(), isTrue);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('step/total drive the "n of 5" label', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.total, TourBeats.all.length);
      expect(d.step, 0);
      d.onMoment(TourMoment.rolled);
      expect(d.step, 1);
    });
  });

  group('MetaState.tourSeenVersion', () {
    test('defaults to 0, round-trips through json', () {
      final m = MetaState();
      expect(m.tourSeenVersion, 0);
      // 0 is omitted from json to keep old-save byte-compat.
      expect(m.toJson().containsKey('tourSeenVersion'), isFalse);
      m.tourSeenVersion = tourVersion;
      final back = MetaState.fromJson(m.toJson());
      expect(back.tourSeenVersion, tourVersion);
    });

    test('old save json (no key) deserializes to 0 — veterans re-tour', () {
      final old = MetaState(tutorialSeen: true).toJson();
      old.remove('tourSeenVersion');
      expect(MetaState.fromJson(old).tourSeenVersion, 0);
    });

    test('cloud merge keeps the max stamp both ways', () {
      final a = MetaState(tourSeenVersion: tourVersion);
      final b = MetaState();
      expect(mergeMetaStates(a, b).tourSeenVersion, tourVersion);
      expect(mergeMetaStates(b, a).tourSeenVersion, tourVersion);
    });
  });

  group('tour in combat (widget)', () {
    testWidgets('fresh profile: tour shows in first fight, tips stay quiet', (
      tester,
    ) async {
      final c = GameController(); // tourSeenVersion 0 → tour must run
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      if (!await walkToFight(tester, c)) return; // no early fight; fine
      await pumpFor(tester, 400);
      expect(c.tour.running, isTrue);
      expect(c.tour.active, TourBeats.roll);
      // The overlay's beat card and SKIP are on screen; no context tip.
      expect(find.text('YOUR DICE'), findsOneWidget);
      expect(find.text('SKIP'), findsOneWidget);
      expect(find.text('Roll, then spend'), findsNothing);
      // The game is live under the scrim: tap ROLL — the beat advances.
      await tester.tap(find.text('Roll'), warnIfMissed: false);
      await pumpFor(tester, 700);
      expect(c.tour.active, TourBeats.pick);
      expect(find.text('PICK ONE UP'), findsOneWidget);
    });

    testWidgets('skip stamps the version and never re-runs', (tester) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      if (!await walkToFight(tester, c)) return;
      await pumpFor(tester, 400);
      expect(c.tour.running, isTrue);
      await tester.tap(find.text('SKIP'));
      await pumpFor(tester, 300);
      expect(c.tour.running, isFalse);
      expect(c.meta.tourSeenVersion, tourVersion);
      expect(find.text('SKIP'), findsNothing);
    });

    testWidgets('stamped profile: no tour, tips run as before', (
      tester,
    ) async {
      final c = GameController();
      c.meta.tourSeenVersion = tourVersion;
      c.tour = TourDirector(seenVersion: tourVersion);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      if (!await walkToFight(tester, c)) return;
      await pumpFor(tester, 400);
      expect(c.tour.running, isFalse);
      expect(find.text('SKIP'), findsNothing);
    });
  });
}
