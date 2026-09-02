// test/set_stones_test.dart — v0.180.0 The Set Stones.
//
// The Codex covered enemies, relics, delvers, places, rules, marks and dice
// — and never the four keystones, the one run-long rule a delver sets after
// the first won fight. Four entries now close the tools of the trade, in
// their own lane between THE MARKS and THE DICE. Pins: the entries mirror
// keystonesOrder exactly; priced like dice and marks; ≤200 chars; banned
// words; they buy through the standard codex flow; the lane chip and header
// render and resolve the keystone's own name.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/keystones.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';

const bannedWords = [
  'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
  'bet you', 'only today', "can't", 'loser', //
];

void main() {
  test('four keystone entries mirror the live keystones exactly', () {
    final stones = codexEntries.where((e) => e.kind == 'keystone').toList();
    expect(stones.map((e) => e.refId).toList(), keystonesOrder);
    expect(stones.length, 4);
    for (final e in stones) {
      expect(e.id, 'keystone:${e.refId}');
      expect(e.costEmbers, 15, reason: 'tools of the trade price like dice');
      expect(e.text.length, lessThanOrEqualTo(200), reason: e.refId);
      expect(keystones.containsKey(e.refId), isTrue);
      for (final w in bannedWords) {
        expect(e.text.toLowerCase().contains(w), isFalse, reason: e.refId);
      }
    }
    // The stones close the tools of the trade: after the marks, before dice.
    final kinds = codexEntries.map((e) => e.kind).toList();
    expect(kinds.lastIndexOf('rune'), lessThan(kinds.indexOf('keystone')));
  });

  test('keystone entries buy through the standard codex flow', () {
    final c = GameController();
    c.meta.embers = 25;
    expect(c.buyCodexEntry('keystone:ashen_edge'), isTrue);
    expect(c.meta.ownedCodex, contains('keystone:ashen_edge'));
    expect(c.meta.embers, 10);
    expect(c.buyCodexEntry('keystone:ashen_edge'), isFalse, reason: 'owned');
    expect(c.buyCodexEntry('keystone:twin_bellows'), isFalse, reason: 'broke');
  });

  testWidgets('the Keystones lane renders its header and names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final chip = find.byKey(const ValueKey('codex-lane-stones'));
    expect(chip, findsOneWidget);
    expect(find.text('THE KEYSTONES'), findsNothing, reason: 'lazy, below');
    // Walk there exactly as a thumb would: the chip.
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('THE KEYSTONES'), findsOneWidget);
    expect(find.text('Twin Bellows'), findsOneWidget);
    expect(find.text('Ashen Edge'), findsOneWidget);
    // The kind tag shows on owned entries only (unowned show the price).
    expect(find.text('KEYSTONE'), findsNothing);
    expect(find.text('15'), findsWidgets);
  });
}
