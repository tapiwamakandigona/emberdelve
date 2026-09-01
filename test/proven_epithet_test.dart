// test/proven_epithet_test.dart — v0.59.0 "The Proven": a tenth epithet
// caps the Provings arc — clear every proving, wear the title. Design
// doc: docs/improvements/v0.59.0-lead-scout.md.
//
// Pins:
//   1. TARGET HONESTY: the_proven's target equals provings.length — a
//      future eleventh proving cannot silently orphan "Clear every
//      proving." (the pin fails loudly and the target gets bumped).
//   2. statValue('provings_cleared') is the REAL Set size, junk-proof.
//   3. The gate: nine clears stay locked, all ten unlock; selectEpithet
//      refuses the locked title and accepts the earned one.
//   4. The shelf renders the card LAST with its honest unlock line, and
//      a worn the Proven flows into the fuller record (v0.57.0) so the
//      Ledger and card remember it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the_proven target equals the live provings count', () {
    expect(epithets['the_proven']!.target, provings.length);
    expect(epithetsOrder.last, 'the_proven');
    expect(epithets['the_proven']!.stat, 'provings_cleared');
  });

  test('provings_cleared statValue is the real set size', () {
    final c = GameController();
    expect(statValue(c.meta, 'provings_cleared'), 0);
    c.meta.provingsCleared.addAll(['first_flame', 'shield_oath']);
    expect(statValue(c.meta, 'provings_cleared'), 2);
  });

  test('nine clears stay locked; all ten unlock and can be worn', () {
    final c = GameController();
    final all = provings.map((p) => p.id).toList();
    c.meta.provingsCleared.addAll(all.take(provings.length - 1));
    expect(c.epithetUnlocked('the_proven'), isFalse);
    c.selectEpithet('the_proven', forChar: 'kindler');
    expect(c.meta.epithetFor('kindler'), isNot('the_proven'));
    c.meta.provingsCleared.add(all.last);
    expect(c.epithetUnlocked('the_proven'), isTrue);
    c.selectEpithet('the_proven', forChar: 'kindler');
    expect(c.meta.epithetFor('kindler'), 'the_proven');
  });

  testWidgets('the shelf renders the Proven last with its honest line', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    // The character list inflates lazily and the epithet shelf sits
    // below a roster that keeps growing — drag to the bottom in fixed
    // steps (scrollUntilVisible's single-element lookup breaks on the
    // lazy list once the roster passed twenty chairs).
    final proven = find.byKey(const ValueKey('epithet-the_proven'));
    for (var i = 0; i < 24 && proven.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump();
    }
    await tester.ensureVisible(proven);
    await tester.pump();
    expect(find.byKey(const ValueKey('epithet-the_proven')), findsOneWidget);
    expect(find.text('Clear every proving.'), findsOneWidget);
  });
}
