// test/guttering_foe_test.dart — v0.87.0 The Guttering Foe.
//
// One shared rule (inTheRed) and its newest voice: the enemy bar turns
// gold with a NEARLY SPENT caption when the foe is inside it. Pure rule
// pins first; then a widget drive proves the live tell both ways.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms / 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pure-controller walk into the first fight of kindler seed 1.
GameController atFight() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'player_turn' && guard++ < 20) {
    final map = c.state!['map'] as Map;
    final pos = map['position'] as int;
    final edges = ((map['edges'] as Map)['$pos'] as List).cast<int>();
    c.apply({'type': 'choose_node', 'node': edges.first});
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
  }
  expect(c.phase, 'player_turn');
  return c;
}

StatBar enemyBar(WidgetTester tester) => tester
    .widgetList<StatBar>(find.byType(StatBar))
    .firstWhere((b) => b.label.startsWith('ENEMY HP'));

void main() {
  test('inTheRed: alive and at or under 30%, boundary inclusive', () {
    expect(inTheRed(9, 30), isTrue); // exactly 30%
    expect(inTheRed(10, 30), isFalse); // one past
    expect(inTheRed(1, 30), isTrue);
    expect(inTheRed(0, 30), isFalse); // dead is not "close"
  });

  testWidgets('a foe inside the rule gutters gold and says so', (tester) async {
    final c = atFight();
    c.sim!.enemy!['max_hp'] = 30;
    c.sim!.enemy!['hp'] = 9;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 800);
    expect(find.textContaining('NEARLY SPENT'), findsOneWidget);
    expect(enemyBar(tester).color, EmberColors.gold);
  });

  testWidgets('a healthy foe keeps the plain red bar', (tester) async {
    final c = atFight();
    c.sim!.enemy!['max_hp'] = 30;
    c.sim!.enemy!['hp'] = 10;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 800);
    expect(find.textContaining('NEARLY SPENT'), findsNothing);
    expect(enemyBar(tester).color, EmberColors.danger);
  });
}
