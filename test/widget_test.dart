// test/widget_test.dart — UI smoke test: the title renders and a delve starts
// into the map. Uses a controller with no persisted run (boot skipped so no
// path_provider dependency in the test host).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  testWidgets('title renders and Delve enters the map', (tester) async {
    final c = GameController(); // no boot(): starts at title
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await tester.pumpAndSettle();

    expect(find.text('EMBERDELVE'), findsOneWidget);
    expect(find.text('Delve'), findsOneWidget);

    // Start a run directly (avoids the wall-clock seed path being flaky).
    c.startRun(character: 'kindler');
    await tester.pumpAndSettle();

    // Map phase renders the top bar resources.
    expect(c.phase, equals('map'));
    expect(find.text('GOLD'), findsOneWidget);
    expect(find.text('EMBERS'), findsWidgets);
  });

  testWidgets('character screen lists all delvers', (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a delver'));
    await tester.pumpAndSettle();
    // Top cards render; lower ones are lazily built when scrolled into view.
    expect(find.text('The Kindler'), findsOneWidget);
    expect(find.text('The Warden'), findsOneWidget);
    expect(find.text('NEXT UNLOCK — THE WARDEN'), findsOneWidget);
    await tester.dragUntilVisible(find.text('The Ascetic'),
        find.byType(Scrollable).first, const Offset(0, -200));
    expect(find.text('The Ascetic'), findsOneWidget);
  });
}
