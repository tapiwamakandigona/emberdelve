// test/old_foe_test.dart — v0.78.0 The Old Foe.
//
// The Ledger names the enemy that has ended more delves than any other,
// read from meta.enemyFellTo. Flat statement, no goading (§Ethics). Two
// falls make a foe; unknown ids are skipped; ties resolve to enemies
// authoring order so the answer never flickers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/meta/meta.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('oldFoe picks the most falls; ties go to authoring order', () {
    final m = MetaState();
    m.enemyFellTo.addAll({'ash_rat': 3, 'soot_shade': 5, 'cinder_wisp': 2});
    final foe = oldFoe(m)!;
    expect(foe.id, 'soot_shade');
    expect(foe.falls, 5);

    // Tie at 3: cinder_wisp precedes ash_rat in enemiesOrder.
    final tied = MetaState();
    tied.enemyFellTo.addAll({'ash_rat': 3, 'cinder_wisp': 3});
    expect(oldFoe(tied)!.id, 'cinder_wisp');
  });

  test('one fall is bad luck, not a foe; unknown ids are skipped', () {
    final m = MetaState();
    m.enemyFellTo['ash_rat'] = 1;
    expect(oldFoe(m), isNull, reason: 'threshold is two falls');
    expect(oldFoe(MetaState()), isNull, reason: 'empty record, no row');

    // A retired id with the top count must not crash or win.
    final odd = MetaState();
    odd.enemyFellTo.addAll({'gone_forever': 9, 'ash_rat': 2});
    expect(oldFoe(odd)!.id, 'ash_rat');
  });

  testWidgets('the Ledger row appears at two falls, absent before', (
    tester,
  ) async {
    final c = GameController();
    c.meta.enemyFellTo['ash_rat'] = 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('old-foe')), findsNothing);

    c.meta.enemyFellTo['ash_rat'] = 4;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('old-foe')), findsOneWidget);
    expect(find.textContaining('×4'), findsOneWidget);
  });
}
