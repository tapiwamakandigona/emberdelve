// test/relic_inventory_ui_test.dart — #97: the in-run relic inventory
// reaches the player. The top bar's relic pip and the pause menu both open a
// read-only panel listing owned relics with their effect text, and the
// character's starting relic is tagged. Effects were previously invisible
// mid-run (itch feedback, 0.26.0 devlog).
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GameController _inRun({String character = 'warden'}) {
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.meta.unlockedCharacters.add(character);
  c.startRun(character: character, seed: 5, boons: false);
  return c;
}

void main() {
  testWidgets('relic pip opens the inventory with the starting relic tagged', (
    tester,
  ) async {
    final c = _inRun(); // warden starts with iron_scale
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);

    // The pip is the only 'Relic inventory' semantics button on screen.
    await tester.tap(find.byKey(const ValueKey('topbar-relics')));
    await _settle(tester);

    expect(find.text('RELICS · 1'), findsOneWidget);
    expect(find.text(relics['iron_scale']!.name), findsOneWidget);
    expect(find.text(relics['iron_scale']!.text), findsOneWidget);
    expect(find.text('STARTING'), findsOneWidget);

    // Close returns to the run untouched.
    await tester.tap(find.text('Close'));
    await _settle(tester);
    expect(find.text('RELICS · 1'), findsNothing);
    expect((c.state!['run'] as Map)['relics'], ['iron_scale']);
  });

  testWidgets('pause menu reaches the same panel', (tester) async {
    final c = _inRun();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('Pause menu'));
    await _settle(tester);
    expect(find.text('Relics'), findsOneWidget);
    await tester.tap(find.text('Relics'));
    await _settle(tester);

    expect(find.text('RELICS · 1'), findsOneWidget);
  });

  testWidgets('kindler (no starting relic) gets the empty state', (
    tester,
  ) async {
    final c = _inRun(character: 'kindler');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('topbar-relics')));
    await _settle(tester);

    expect(find.text('RELICS · 0'), findsOneWidget);
    expect(find.text('STARTING'), findsNothing);
    expect(
      find.textContaining('No relics yet'),
      findsOneWidget,
    );
  });
}
