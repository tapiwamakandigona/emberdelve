// test/scoped_rebuild_test.dart — the combat rebuild-scope pin.
//
// GameRoot hands combat ONE widget instance across controller
// notifications (see _scoped in game_root.dart): Element.updateChild
// short-circuits on the identical widget, so a sim command never re-runs
// CombatScreen.build() top to bottom — the screen's own per-field
// listeners rebuild only the sections whose data moved. That guarantee
// lived in a comment; one refactor could silently regress it back to
// whole-screen rebuilds. This pins it, with the shop screen as the
// sensitivity control (deliberately _whole: a fresh instance per
// notification proves the probe can tell the two apart).
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walk the kindler to the given phase with the autoplay bot.
GameController walkTo(String phase, {int seed = 7}) {
  final c = GameController();
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != phase &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, phase, reason: 'seed $seed walk must reach $phase');
  return c;
}

Future<void> pumpFrames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a controller notification does NOT rebuild CombatScreen', (
    tester,
  ) async {
    final c = walkTo('player_turn');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFrames(tester);
    final before = tester.widget(find.byType(CombatScreen));
    c.notifyListeners();
    await pumpFrames(tester, 3);
    final after = tester.widget(find.byType(CombatScreen));
    expect(
      identical(before, after),
      isTrue,
      reason:
          'combat is a scoped screen: GameRoot must hand the framework the '
          'IDENTICAL CombatScreen instance across notifications so '
          'Element.updateChild short-circuits (game_root.dart _scoped)',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('control: a _whole screen rebuilds on notification', (
    tester,
  ) async {
    final c = walkTo('shop');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFrames(tester);
    final before = tester.widget(find.byType(ShopScreen));
    c.notifyListeners();
    await pumpFrames(tester, 3);
    final after = tester.widget(find.byType(ShopScreen));
    expect(
      identical(before, after),
      isFalse,
      reason:
          'the shop is deliberately _whole (rebuilt per notification); if '
          'this ever flips, the probe above has lost its sensitivity',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
