// test/codex_lanes_test.dart — Codex Lanes.
//
// The book is 132 entries across eight sections; reaching THE DICE was a
// marathon of scrolling. One chip per section, pinned under the app bar,
// walks the lazy list to that section's header (widgets.dart
// walkToAnchor — linear glide, eased settle, walks BOTH directions).
// Chips navigate; they never filter — the whole book stays on one page.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFrames(WidgetTester tester, [int n = 40]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> pumpCodex(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  testWidgets('eight lane chips render, one per section', (tester) async {
    await pumpCodex(tester);
    for (final id in [
      'world',
      'company',
      'enemies',
      'relics',
      'rules',
      'marks',
      'stones',
      'dice',
    ]) {
      expect(
        find.byKey(ValueKey('codex-lane-$id')),
        findsOneWidget,
        reason: 'lane chip $id must render',
      );
    }
  });

  testWidgets('the DICE lane walks the lazy list to THE DICE', (tester) async {
    await pumpCodex(tester);
    // Far below the fold: the lazy list has not inflated it.
    expect(find.text('THE DICE'), findsNothing);
    // The dice chip sits beyond a 390px viewport in the horizontal chip
    // row — bring it in first, exactly as a thumb would.
    await tester.ensureVisible(find.byKey(const ValueKey('codex-lane-dice')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-lane-dice')));
    await pumpFrames(tester);
    expect(
      find.text('THE DICE'),
      findsOneWidget,
      reason: 'the walk must inflate and land the section header',
    );
    // THE DICE is the last section: the list bottoms out before the
    // header can reach the top, so 'visible in the viewport' is the pin.
    final y = tester.getTopLeft(find.text('THE DICE')).dy;
    expect(y, lessThan(844), reason: 'the header settles in the viewport');
    expect(y, greaterThanOrEqualTo(0));
  });

  testWidgets('the WORLD lane walks back UP from the bottom', (tester) async {
    await pumpCodex(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('codex-lane-dice')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-lane-dice')));
    await pumpFrames(tester);
    expect(find.text('THE DICE'), findsOneWidget);
    // Now the top is deflated; the walk must go the other way. The chip
    // row is still scrolled right from reaching the dice chip — bring the
    // world chip back in before tapping, as a thumb would.
    await tester.ensureVisible(find.byKey(const ValueKey('codex-lane-world')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-lane-world')));
    await pumpFrames(tester);
    expect(
      find.text('THE WORLD'),
      findsOneWidget,
      reason: 'preferUp walk must reach a section above the viewport',
    );
    final y = tester.getTopLeft(find.text('THE WORLD')).dy;
    expect(y, lessThan(300));
  });
}
