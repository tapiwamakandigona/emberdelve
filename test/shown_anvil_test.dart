// test/shown_anvil_test.dart — v0.139.0 The Shown Anvil.
//
// The temper system's front-door tip: fires once, at the first rest fire
// where a temper is still available, and never teaches an absent button.
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('director: fires once, only with a live anvil, respects the rules', () {
    final d = TipDirector(<String>{});
    expect(
      d.onRestArrival(canTemper: false),
      isNull,
      reason: 'a spent anvil teaches nothing',
    );
    expect(d.onRestArrival(canTemper: true), ContextTips.firstAnvil);
    expect(
      d.onRestArrival(canTemper: true),
      isNull,
      reason: 'one tip at a time — still active',
    );
    d.dismiss();
    expect(d.onRestArrival(canTemper: true), isNull, reason: 'once ever');
    expect(d.seen, contains(ContextTips.firstAnvil));
  });

  test('the one-at-a-time rule holds against other tips', () {
    final d = TipDirector(<String>{});
    expect(d.onMapArrival(), ContextTips.whatsADelve);
    expect(
      d.onRestArrival(canTemper: true),
      isNull,
      reason: 'the delve card is up — no queue, no wall',
    );
    d.dismiss();
    expect(d.onRestArrival(canTemper: true), ContextTips.firstAnvil);
  });

  testWidgets('the card shows at the first rest and dismisses forever', (
    tester,
  ) async {
    final c = GameController();
    c.meta.tipsSeen.addAll(
      ContextTips.all.where((t) => t != ContextTips.firstAnvil),
    );
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    c.startRun(character: 'kindler', seed: 5, boons: false);
    c.sim!.phase = 'rest';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('THE SMITH IS IN'), findsOneWidget);
    await tester.tap(find.text('THE SMITH IS IN'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('THE SMITH IS IN'), findsNothing);
    expect(c.meta.tipsSeen, contains(ContextTips.firstAnvil));
    expect(
      c.meta.tutorialSeen,
      isTrue,
      reason: 'last unseen tip dismissed flips the legacy flag',
    );
  });

  test('the card copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    const copy =
        'THE SMITH IS IN This fire can temper a die: pick one face and '
        'mark it with a rune. Two marks a delve; resting costs neither.';
    final low = copy.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
