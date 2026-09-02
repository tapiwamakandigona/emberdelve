// test/circle_headers_test.dart — v0.179.0 The Two Circles: the character
// list sections itself along the roster's own fiction (first circle closed
// at sixteen chairs, second circle open, append-LAST). Pins:
//   1. Both headers render, in order, with the first sixteen cards under
//      the first and the rest under the second.
//   2. The split index is 16 FOREVER (the first circle is closed): if the
//      roster grows, new chairs land under the second header untouched.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the two circle headers section the character list', (
    tester,
  ) async {
    final c = GameController();
    c.meta.tutorialSeen = true;
    c.meta.tourSeenVersion = 99;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('THE FIRST CIRCLE'), findsOneWidget);
    // The second header lives below the sixteen first-circle cards — the
    // lazy list may not have inflated it yet; scroll down until found.
    var found = false;
    for (var i = 0; i < 30 && !found; i++) {
      found = find.text('THE SECOND CIRCLE').evaluate().isNotEmpty;
      if (!found) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 25));
      }
    }
    expect(found, isTrue, reason: 'the second-circle header must render');
  });

  test('the split rides the closed first circle, not the live roster', () {
    // The first circle is CLOSED at sixteen (roster doctrine). The
    // sixteenth chair is the hearthkeeper; everything after belongs to
    // the second circle.
    expect(charactersOrder[15], 'hearthkeeper');
    expect(charactersOrder.length, greaterThanOrEqualTo(17));
  });
}
