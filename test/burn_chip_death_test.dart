// test/burn_chip_death_test.dart — critic round 1 issue C1-05.
//
// Round-1 plates showed the foe's burn chip ("🔥 11") still sitting at the
// feet of a foe that had just died, with the blood pool painted OVER its
// digits (040, 021) and a "🔥 1" chip riding the dissolve (026). The intent
// badge already fades at 0 HP; the burn chip had no such rule, and the floor
// stains layer was drawn after (above) the combatants.
//
// This test lands a real lethal blow on a burning foe through the production
// controls and asserts, at two phone sizes and with and without Reduce
// Motion:
//   • before the blow the burn chip is shown at full opacity;
//   • once the blow has landed (+240 ms, the badge's own window) the chip is
//     gone, exactly like the intent badge;
//   • the floor stains are painted BEFORE (below) the burn chip — in a Stack
//     render children paint in child order, so a depth-first walk of the
//     render tree gives paint order.
// The foe's HP and burn are FIXTURES; nothing about the sim's rules moves.
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/gore.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart'
    show alphaOf, button, loadRealFonts, makeController, toFight;

Finder _burnChip() => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_StatusChip',
);

Finder _stainsPaint() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is FloorStainsPainter,
);

/// Depth-first render order from the root (== paint order inside Stacks).
List<RenderObject> _paintOrder(WidgetTester tester) {
  final out = <RenderObject>[];
  void walk(RenderObject r) {
    out.add(r);
    r.visitChildren(walk);
  }

  walk(tester.binding.renderViews.first);
  return out;
}

Future<void> burnKillCase(
  WidgetTester tester, {
  required Size size,
  required bool reduced,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  Motion.instance.update(setting: reduced ? 'on' : 'off');
  addTearDown(() => Motion.instance.update(setting: 'off'));
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final rolled = (c.sim!.player['rolled'] as List).length;
  var die = 0, value = 0;
  for (var d = 1; d <= rolled; d++) {
    final r = resolveAssignment(
      player: c.sim!.player,
      enemy: c.sim!.enemy!,
      run: c.sim!.run,
      die: d,
      action: 'attack',
    );
    if (r.allowed && r.value >= 2) {
      die = d;
      value = r.value;
      break;
    }
  }
  expect(die, greaterThan(0), reason: 'seed 1 must roll an attack die ≥ 2');
  // FIXTURE: a burning foe the chosen die kills exactly.
  c.sim!.enemy!['hp'] = value;
  c.sim!.enemy!['block'] = 0;
  c.sim!.enemy!['burn'] = 11;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();

  expect(_burnChip(), findsOneWidget, reason: 'the burning foe shows a chip');
  expect(
    alphaOf(_burnChip().evaluate().single),
    closeTo(1.0, 0.01),
    reason: 'before the blow the chip is fully visible',
  );

  final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
  await tester.tap(dice.at(die - 1));
  await tester.pump();
  await tester.tap(button('Attack'));

  int? landedAt;
  var checked = 0, orderChecked = 0;
  final problems = <String>[];
  for (var ms = 40; ms <= 2600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    if (find.byType(CombatScreen).evaluate().isEmpty) break;
    if (find.byType(DamagePop).evaluate().isNotEmpty) landedAt ??= ms;
    final chips = _burnChip().evaluate().toList();
    if (landedAt != null && ms >= landedAt + 240) {
      checked++;
      for (final e in chips) {
        final a = alphaOf(e);
        if (a > 0.05) {
          problems.add('t=${ms}ms  dead foe still shows its burn chip (α=$a)');
        }
      }
    }
    // Wherever both exist, the floor stains paint under the chip.
    final stains = _stainsPaint().evaluate().toList();
    if (stains.isNotEmpty && chips.isNotEmpty) {
      orderChecked++;
      final order = _paintOrder(tester);
      final si = order.indexOf(stains.single.renderObject!);
      final ci = order.indexOf(chips.single.renderObject!);
      if (si > ci) {
        problems.add('t=${ms}ms  floor stains paint over the burn chip');
      }
    }
  }
  expect(landedAt, isNotNull, reason: 'the lethal blow lands');
  expect(checked, greaterThan(3), reason: 'frames after the blow were seen');
  expect(orderChecked, greaterThan(0), reason: 'stains and chip coexisted');
  expect(problems, isEmpty, reason: problems.take(12).join('\n'));
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {'320x568': Size(320, 568), '360x800': Size(360, 800)};
  for (final entry in sizes.entries) {
    for (final reduced in [false, true]) {
      testWidgets(
        'burn chip leaves with the dead foe, under no stain '
        '(${entry.key}, reduce motion ${reduced ? 'on' : 'off'})',
        (t) async {
          await burnKillCase(t, size: entry.value, reduced: reduced);
        },
      );
    }
  }
}
