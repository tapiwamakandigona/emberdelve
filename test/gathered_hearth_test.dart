// test/gathered_hearth_test.dart — v0.42.0 The Gathered Hearth.
//
// The title fire seats every unlocked delver. These tests pin the two load-
// bearing promises: a fresh profile renders exactly one delver (the kindler,
// in their pre-v0.42.0 spot), and a full company seats all five around the
// fire — left side facing right (unflipped), right side flipped toward the
// flames — in the alternating unlock-order arrangement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('fresh profile: exactly one delver at the hearth', (
    tester,
  ) async {
    final c = GameController(); // no boot(): starts at title
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    expect(find.byKey(const ValueKey('gathered-hearth')), findsOneWidget);
    expect(
      find.byKey(ValueKey('hearth-$defaultCharacter')),
      findsOneWidget,
    );
    for (final id in charactersOrder) {
      if (id == defaultCharacter) continue;
      expect(
        find.byKey(ValueKey('hearth-$id')),
        findsNothing,
        reason: 'locked delver $id must not appear at the hearth',
      );
    }
    // The lone kindler keeps the classic pose: unflipped, full 72px.
    final lone = tester.widget<SpriteView>(
      find.byKey(ValueKey('hearth-$defaultCharacter')),
    );
    expect(lone.flipX, isFalse);
    expect(lone.height, 72.0);
    await pumpFor(tester, 400);
  });

  testWidgets('full company: all five delvers gather, facing the fire', (
    tester,
  ) async {
    final c = GameController();
    c.meta.unlockedCharacters.addAll(charactersOrder);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    for (final id in charactersOrder) {
      expect(
        find.byKey(ValueKey('hearth-$id')),
        findsOneWidget,
        reason: 'unlocked delver $id must appear at the hearth',
      );
    }
    // Alternating seats by unlock order: even index sits left of the fire
    // (unflipped), odd index sits right (flipped toward the flames).
    for (final (i, id) in charactersOrder.indexed) {
      final sprite = tester.widget<SpriteView>(
        find.byKey(ValueKey('hearth-$id')),
      );
      expect(
        sprite.flipX,
        i.isOdd,
        reason: '$id (unlock index $i) faces the wrong way',
      );
      expect(sprite.height, 58.0, reason: 'a full hearth seats at 58px');
    }
    await pumpFor(tester, 400);
  });
}
