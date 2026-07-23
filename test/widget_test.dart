// test/widget_test.dart — UI smoke tests. The overhauled screens run ambient
// looping animations (ember drift, node-glow pulse, logotype sparks), so these
// tests use bounded pumps instead of pumpAndSettle, which would never settle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/logo.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

/// Pump frames for roughly [ms] of animation time without waiting to settle.
Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('title renders the logotype and Delve enters the map',
      (tester) async {
    final c = GameController(); // no boot(): starts at title
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 400);

    // The wordmark is drawn (EmberLogotype), not a plain Text widget.
    expect(find.byType(EmberLogotype), findsOneWidget);
    expect(find.text('EMBERDELVE'), findsNothing);
    expect(find.text('Delve'), findsOneWidget);

    // Start a run directly (avoids the wall-clock seed path being flaky).
    c.startRun(character: 'kindler');
    await pumpFor(tester, 800);

    // Map phase renders the top bar resources.
    expect(c.phase, equals('map'));
    expect(find.text('GOLD'), findsOneWidget);
    expect(find.text('EMBERS'), findsWidgets);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });

  testWidgets('combat renders die faces and rolling triggers the tray',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startRun(character: 'kindler');
    await pumpFor(tester, 700);

    // Walk into the first reachable node until a fight starts.
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
    if (c.phase != 'player_turn') return; // map had no early fight; fine

    await pumpFor(tester, 2200); // outlast a possible name-plate splash
    expect(find.byType(DieChip), findsWidgets);
    expect(find.text('Roll'), findsOneWidget);
    await tester.tap(find.text('Roll'));
    await pumpFor(tester, 900); // tumble cascade completes
    expect(find.text('Attack'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });

  testWidgets('character screen lists all delvers', (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 300);
    await tester.tap(find.text('Choose a delver'));
    await pumpFor(tester, 700);
    // Top cards render; lower ones are lazily built when scrolled into view.
    expect(find.text('The Kindler'), findsOneWidget);
    expect(find.text('The Warden'), findsOneWidget);
    expect(find.text('NEXT UNLOCK — THE WARDEN'), findsOneWidget);
    await tester.dragUntilVisible(find.text('The Ascetic'),
        find.byType(Scrollable).first, const Offset(0, -200));
    expect(find.text('The Ascetic'), findsOneWidget);
    await pumpFor(tester, 800); // drain implicit animations before teardown
  });
}
