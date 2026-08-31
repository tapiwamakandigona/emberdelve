// test/spoken_dice_test.dart — v0.116.0 The Spoken Dice.
//
// Codex 'die' entries: one story per BASE CUT (d4/d6/d8/d10/d12), priced
// like common lore, named from the dice catalog so a rename can never
// leave the Codex lying. The tempered variants carry no entries — they
// are the same cuts re-promised at the forge.
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const baseCuts = ['d4', 'd6', 'd8', 'd10', 'd12'];

void main() {
  test('the codex speaks exactly the five base cuts, shallow to deep', () {
    final refs = codexEntries
        .where((e) => e.kind == 'die')
        .map((e) => e.refId)
        .toList();
    expect(refs, baseCuts);
    for (final e in codexEntries.where((e) => e.kind == 'die')) {
      expect(e.id, 'die:${e.refId}');
      expect(e.costEmbers, 15);
      expect(e.text.trim().length, greaterThan(40));
      // Name authority is the dice catalog (anti-lying rule).
      expect(dice[e.refId]!.name, isNotEmpty);
    }
    // Every base cut is a real, un-modded die of its printed size.
    for (final id in baseCuts) {
      expect(dice[id]!.mods, isEmpty, reason: '$id is the plain cut');
    }
  });

  test('buying a die story spends embers and unseals it', () {
    final c = GameController();
    c.meta.embers = 20;
    expect(c.buyCodexEntry('die:d6'), isTrue);
    expect(c.meta.embers, 5);
    expect(c.meta.ownedCodex, contains('die:d6'));
    expect(c.buyCodexEntry('die:d12'), isFalse, reason: 'broke');
  });

  testWidgets('THE DICE closes the book, after the relics', (tester) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.text('THE DICE'),
      400,
      scrollable: scrollable,
      maxScrolls: 400,
    );
    expect(find.text('THE DICE'), findsOneWidget);
    // v0.131.0: THE RULES sits above; scroll on to the first die card
    // (the header can land at the viewport edge with the card below it).
    await tester.scrollUntilVisible(
      find.text('Ember Die'),
      400,
      scrollable: scrollable,
      maxScrolls: 40,
    );
    expect(find.text('Ember Die'), findsOneWidget);
  });

  test('spoken dice copy is honest (no pressure language)', () {
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
    for (final e in codexEntries.where((e) => e.kind == 'die')) {
      final low = e.text.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: '${e.id} banned: $b');
      }
    }
  });
}
