// test/dealt_hand_test.dart — THE DEALT HAND (fx.dart DealtIn):
//   1. The boon hand deals in staggered — mid-deal, card 1 is further along
//      than card 3; the hand is fully present in the tree (and to semantics)
//      from the first frame.
//   2. Settled state is the identity: after the deal every card sits at
//      opacity 1.0, and taps work exactly as before (widget_test.dart's
//      700ms-then-tap contract).
//   3. Reduce-motion renders the hand settled immediately — no deal at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

double _cardOpacity(WidgetTester tester, String key) {
  final o = tester.widget<Opacity>(
    find
        .ancestor(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Opacity),
        )
        .first,
  );
  return o.opacity;
}

void main() {
  testWidgets('boon hand deals in staggered, then settles to identity', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', boons: true, seed: 1);
    expect(c.phase, 'boon');

    // The screen mounts mid phase-fade (PhaseSwitcher), so walk forward in
    // small steps and catch the deal the moment card 1 starts moving.
    var early1 = 0.0;
    for (var t = 0; t < 1000; t += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byKey(const ValueKey('boon-1')).evaluate().isNotEmpty) {
        early1 = _cardOpacity(tester, 'boon-1');
        if (early1 > 0.05) break;
      }
    }
    expect(early1, greaterThan(0.05), reason: 'deal never started');
    // The full hand exists already — nothing pops in later.
    for (var i = 1; i <= 3; i++) {
      expect(find.byKey(ValueKey('boon-$i')), findsOneWidget);
    }
    final early3 = _cardOpacity(tester, 'boon-3');
    expect(
      early1,
      greaterThan(early3),
      reason: 'card 1 deals before card 3 (stagger)',
    );

    // Settled: identity opacity on every card, well before the 700ms the
    // older tests pump before tapping.
    await pumpFor(tester, 550);
    for (var i = 1; i <= 3; i++) {
      expect(_cardOpacity(tester, 'boon-$i'), 1.0);
    }
    await pumpFor(tester, 800); // drain before teardown
  });

  testWidgets('reduce-motion skips the deal entirely', (tester) async {
    Motion.instance.update(setting: 'on');
    addTearDown(() => Motion.instance.update(setting: 'system'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Scaffold(
          body: DealtIn(index: 2, child: Text('card', key: ValueKey('card'))),
        ),
      ),
    );
    // First frame, zero pumps of animation time: already settled.
    expect(_cardOpacity(tester, 'card'), 1.0);
  });
}
