// test/motion_ui_test.dart — The Still Flame in the UI (v0.16.0).
//
//   1. ShakeBox.shake() is a no-op under reduce (no displacement frames).
//   2. EmberDrift renders nothing under reduce — and comes back when the
//      setting flips off mid-session (the title stays live).
//   3. DamagePop under reduce shows the number without Transform motion.
//   4. Settings: the three-way selector highlights the choice and writes
//      it through to the resolver.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  tearDown(Motion.instance.reset);

  testWidgets('shake is a no-op under reduce', (tester) async {
    Motion.instance.update(setting: 'on');
    final key = GlobalKey<ShakeBoxState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: ShakeBox(key: key, child: const Text('steady')),
      ),
    );
    key.currentState!.shake(1.0);
    await tester.pump(const Duration(milliseconds: 60));
    final transform = tester.widget<Transform>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(Transform))
          .first,
    );
    expect(transform.transform.getTranslation().length, 0.0,
        reason: 'reduced shake must not displace the subtree');
  });

  testWidgets('ember drift vanishes under reduce and returns when off', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Scaffold(body: EmberDrift(count: 10)),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(EmberDrift),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    Motion.instance.update(setting: 'off');
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(EmberDrift),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('damage pop keeps the number, drops the motion', (tester) async {
    Motion.instance.update(setting: 'on');
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Scaffold(
          body: Stack(
            children: [DamagePop(amount: 7, onDone: () => done = true)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('-7'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('-7'), matching: find.byType(Transform)),
      findsNothing,
      reason: 'reduced pop renders without Transform motion',
    );
    await pumpFor(tester, 700);
    expect(done, isTrue, reason: 'onDone still fires on the same clock');
  });

  testWidgets('settings selector writes through to the resolver', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: const SettingsScreen()),
    );
    await tester.pump();
    final reduced = find.byKey(const ValueKey('reduce-motion-on'));
    await tester.scrollUntilVisible(reduced, 120);
    await tester.tap(reduced);
    await tester.pump(const Duration(milliseconds: 200));
    expect(Motion.instance.setting, 'on');
    expect(Motion.instance.reduced, isTrue);
    await tester.tap(find.byKey(const ValueKey('reduce-motion-off')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(Motion.instance.setting, 'off');
    expect(Motion.instance.reduced, isFalse);
  });
}
