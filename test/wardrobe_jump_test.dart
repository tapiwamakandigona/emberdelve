// test/wardrobe_jump_test.dart — the Wardrobe lift.
//
// Sixteen delver cards stand between the app bar and the dressing
// shelves. The 'WARDROBE' app-bar action must carry the player straight
// there — walking the lazy list until the anchor inflates, then settling
// it in view — because nobody should scroll past the whole company to
// change a dye.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> fullRoster() async {
    final c = GameController();
    c.meta.unlockedCharacters.addAll(charactersOrder);
    return c;
  }

  testWidgets('the lift exists and the wardrobe starts off-screen', (
    tester,
  ) async {
    final c = await fullRoster();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('wardrobe-jump')), findsOneWidget);
    // With the full company on the roster, the wardrobe header is far
    // below the fold — the reason the lift exists at all.
    expect(find.text('THE WARDROBE'), findsNothing);
  });

  testWidgets('tapping WARDROBE lands the wardrobe header in view', (
    tester,
  ) async {
    final c = await fullRoster();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wardrobe-jump')));
    // The walk animates in short steps. pumpAndSettle would never settle
    // here (delver sprites idle forever), so pump fixed frames instead.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final header = find.text('THE WARDROBE');
    expect(header, findsOneWidget);
    // In view means truly in view: within the screen's bounds.
    final y = tester.getTopLeft(header).dy;
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(y, greaterThanOrEqualTo(0));
    expect(y, lessThan(screen));
  });

  testWidgets('the lift is honest with a one-delver roster too', (
    tester,
  ) async {
    // Fresh meta: only the kindler. The wardrobe is much closer, but the
    // lift must still land on it without overshooting into the vistas.
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wardrobe-jump')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('THE WARDROBE'), findsOneWidget);
  });
}
