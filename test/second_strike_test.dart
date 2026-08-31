// test/second_strike_test.dart — v0.160.0 The Second Strike.
//
// Deepening's front-door tip (v0.155.0 shipped the mechanic with no
// teaching outside the sheet): fires once, at the first rest fire where
// the pool holds a tier-1 mark AND the anvil is live AND the anvil card
// itself is already seen — a player who has never tempered cannot deepen.
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('director: anvil card outranks it; fires once; needs a shallow mark',
      () {
    final d = TipDirector(<String>{});
    // Never-tempered player: the anvil card wins the slot.
    expect(
      d.onRestArrival(canTemper: true, hasShallowMark: true),
      ContextTips.firstAnvil,
    );
    d.dismiss();
    // Anvil seen, no mark in the pool: nothing to deepen, nothing taught.
    expect(d.onRestArrival(canTemper: true), isNull);
    // Anvil seen, shallow mark present: the deepen card.
    expect(
      d.onRestArrival(canTemper: true, hasShallowMark: true),
      ContextTips.deepMark,
    );
    d.dismiss();
    expect(
      d.onRestArrival(canTemper: true, hasShallowMark: true),
      isNull,
      reason: 'once ever',
    );
    expect(d.seen, contains(ContextTips.deepMark));
  });

  test('director: a spent anvil teaches nothing, even with a mark', () {
    final d = TipDirector(<String>{ContextTips.firstAnvil});
    expect(d.onRestArrival(canTemper: false, hasShallowMark: true), isNull);
  });

  test('director: a DEEP mark alone does not re-teach deepening', () {
    // hasShallowMark is the caller's derivation — this pins the contract
    // that the director trusts it (tier-2-only pools pass false).
    final d = TipDirector(<String>{ContextTips.firstAnvil});
    expect(d.onRestArrival(canTemper: true, hasShallowMark: false), isNull);
  });

  testWidgets('the card shows at a marked rest and dismisses forever', (
    tester,
  ) async {
    final c = GameController();
    c.meta.tipsSeen.addAll(
      ContextTips.all.where((t) => t != ContextTips.deepMark),
    );
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    c.startRun(character: 'kindler', seed: 5, boons: false);
    // A tier-1 mark in the pool (the runesmith idiom: inject, then point
    // a pool slot at it).
    (c.sim!.run!['custom_dice'] as Map)['custom_1'] = {
      'base': 'd6',
      'face': 6,
      'rune': 'blade',
    };
    (c.sim!.player['dice'] as List)[0] = 'custom_1';
    c.sim!.phase = 'rest';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('THE SECOND STRIKE'), findsOneWidget);
    await tester.tap(find.text('THE SECOND STRIKE'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('THE SECOND STRIKE'), findsNothing);
    expect(c.meta.tipsSeen, contains(ContextTips.deepMark));
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
        'THE SECOND STRIKE A marked face can be tempered AGAIN: strike '
        'the same rune deeper and it pays more on the same roll — a II '
        'beside the rune says the work is done. Deepening spends a '
        'temper like any other mark.';
    final low = copy.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
