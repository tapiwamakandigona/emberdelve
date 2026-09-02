// test/nearer_fire_test.dart — v0.180.0 "The Nearer Fire".
//
// The run-end summary ran ~2.25 screens on a 360×800 phone and 'Delve again'
// sat 1.4 screens down. It is now a pinned footer: visible on the first frame
// of the summary, at every size, won or lost, with no scroll — and still the
// same fast restart (boon pick included).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in const [Size(320, 568), Size(360, 800), Size(412, 915)]) {
    testWidgets('Delve again is on screen without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = GameController();
      c.meta
        ..tourSeenVersion = tourVersion
        ..tutorialSeen = true
        ..tipsSeen.addAll(ContextTips.all)
        ..lastSeenNewsVersion = currentAppVersion;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: GameRoot(c),
          ),
        ),
      );
      await pumpFor(tester, 300);
      c.startRun(character: 'kindler', seed: 7, boons: true);
      var guard = 0;
      while (guard++ < 4000 && c.phase != 'run_won' && c.phase != 'run_lost') {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      await pumpFor(tester, 2500);
      final again = find.byKey(const ValueKey('delve-again'));
      expect(again, findsOneWidget);
      final rect = tester.getRect(again);
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(rect.top, greaterThanOrEqualTo(0));
      // The summary's own scroll position is untouched (top of the ledger).
      final s = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(s.position.pixels, 0);
      // Same fast restart: straight into the boon pick.
      await tester.tap(again);
      await pumpFor(tester, 600);
      expect(c.phase, 'boon');
      await pumpFor(tester, 800);
    });
  }
}
