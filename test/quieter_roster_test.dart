// test/quieter_roster_test.dart — v0.180.0 "The Quieter Roster".
//
// A locked delver the player cannot afford shows no button (the header
// already names the lock and the price); the moment the embers are there,
// 'Unlock (N embers)' appears and works. Unlocked delvers keep 'Delve as'.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('no dead button on an unaffordable lock; unlock appears with '
      'the embers', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = GameController();
    final warden = characters['warden']!;
    c.meta.embers = warden.unlockEmbers - 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.textContaining('Delve as The Kindler'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
    expect(find.byKey(const ValueKey('unlock-warden')), findsNothing);
    expect(find.textContaining('Unlock ('), findsNothing);

    c.meta.embers = warden.unlockEmbers;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    c.notifyListeners();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await pumpFor(tester, 400);
    final unlock = find.byKey(const ValueKey('unlock-warden'));
    await tester.scrollUntilVisible(unlock, 200);
    await pumpFor(tester, 200);
    expect(unlock, findsOneWidget);
    expect(
      find.textContaining('Unlock (${warden.unlockEmbers} embers)'),
      findsOneWidget,
    );
    await tester.tap(unlock);
    await pumpFor(tester, 400);
    expect(c.meta.isUnlocked('warden'), isTrue);
    expect(find.textContaining('Delve as The Warden'), findsOneWidget);
  });
}
