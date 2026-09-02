// test/held_hand_test.dart — v0.180.0 The Held Hand.
//
// On an ACTION beat of the guided tour only the spotlit anchor is live. A
// fresh-profile plate walk showed END TURN lit and tappable under "PICK ONE
// UP": a stray tap handed the enemy a free turn while the card still asked
// for a die. The bands around the hole now swallow taps; the hole, the
// copy and SKIP are untouched, and with no anchor laid out nothing is held.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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

int turnOf(GameController c) => c.state!['turn'] as int;

void main() {
  testWidgets('END TURN is held while the tour asks for a die', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    if (!await walkToFight(tester, c)) return;
    await pumpFor(tester, 400);
    expect(c.tour.active, TourBeats.roll);

    // Before the roll there is no END TURN on screen (design); the first
    // stray-tap window opens on the pick beat.
    expect(find.text('End turn'), findsNothing);
    final turn0 = turnOf(c);

    // The spotlit ROLL is live: the beat advances by doing.
    await tester.tap(find.text('Roll'), warnIfMissed: false);
    await pumpFor(tester, 700);
    expect(c.tour.active, TourBeats.pick);
    expect(find.text('End turn'), findsOneWidget);

    // Under "PICK ONE UP" a stray END TURN must not hand the enemy a turn.
    await tester.tap(find.text('End turn'), warnIfMissed: false);
    await pumpFor(tester, 900);
    expect(turnOf(c), turn0, reason: 'the enemy gets no free turn');
    expect(c.tour.active, TourBeats.pick);
    expect(find.text('PICK ONE UP'), findsOneWidget);

    // SKIP stays on top of the bands, always.
    await tester.tap(find.text('SKIP'));
    await pumpFor(tester, 300);
    expect(c.tour.running, isFalse);
  });
}
