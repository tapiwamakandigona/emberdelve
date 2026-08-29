// test/ration_preview_test.dart — v0.90.0 "The Counted Ration".
//
// The shop's Field Rations row must promise exactly what the sim's `_heal`
// will deliver: the overheal cap counted in, a full-HP purchase named for
// what it is, and the promise parity-tested against the real buy.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bot-walk a fresh run to the shop (stops AT the phase, before buying).
/// Pinned seeds (kindler easy): 7 = hp 17/30 gold 98 (uncapped),
/// 20 = hp 31/34 amount 8 (NATURAL overheal cap), 6 = hp 30/30 (full).
GameController atShop({int seed = 7}) {
  final c = GameController();
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'shop' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'shop', reason: 'seed $seed must reach a shop');
  return c;
}

Map healSlot(GameController c) => ((c.sim!.shop!['slots'] as List).cast<Map>())
    .lastWhere((s) => s['kind'] == 'heal');

int healSlotIndex(GameController c) {
  final slots = (c.sim!.shop!['slots'] as List).cast<Map>();
  return slots.indexOf(healSlot(c)) + 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('healPreview mirrors the overheal cap exactly', () {
    final c = atShop();
    expect(healPreview(c.sim!, 7), 7, reason: '17/30 takes all 7');
    c.sim!.player['hp'] = 28;
    expect(healPreview(c.sim!, 7), 2, reason: '28/30 caps at 2');
    c.sim!.player['hp'] = 30;
    expect(healPreview(c.sim!, 7), 0, reason: 'full HP heals nothing');
  });

  test('the promise equals the heal the buy then performs (uncapped)', () {
    final c = atShop(); // seed 7: hp 17/30, gold 98
    final amount = healSlot(c)['amount'] as int;
    final promise = healPreview(c.sim!, amount);
    final before = c.sim!.player['hp'] as int;
    c.apply({'type': 'buy', 'slot': healSlotIndex(c)});
    expect(c.sim!.player['hp'], before + promise);
    expect(promise, amount, reason: 'seed 7 is the uncapped case');
  });

  test('the promise equals the heal on a NATURAL overheal cap', () {
    final c = atShop(seed: 20); // hp 31/34, amount 8 — caps at 3
    final amount = healSlot(c)['amount'] as int;
    final promise = healPreview(c.sim!, amount);
    expect(promise, lessThan(amount), reason: 'seed 20 must actually cap');
    final before = c.sim!.player['hp'] as int;
    c.apply({'type': 'buy', 'slot': healSlotIndex(c)});
    expect(c.sim!.player['hp'], before + promise);
    expect(c.sim!.player['hp'], c.sim!.player['max_hp']);
  });

  testWidgets('the shop row prints the counted heal', (tester) async {
    final c = atShop(); // hp 17/30, amount 7
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final row = find.text('Heal 7 HP (17\u00A0to\u00A024)');
    await tester.scrollUntilVisible(
      row,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(row, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a full-HP ration is named for what it is', (tester) async {
    // v0.114.0 re-anchor: seed 6 no longer shops at full HP; seed 10 does.
    final c = atShop(seed: 10); // hp 30/30
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final row = find.text('Fully rested — heals nothing');
    await tester.scrollUntilVisible(
      row,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(row, findsOneWidget);
    expect(find.textContaining('Heal 7 HP'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
