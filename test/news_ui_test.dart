// test/news_ui_test.dart — The Hearthside Post in the UI (v0.15.0).
//
//   1. A profile that last saw an older release gets the panel on the
//      title screen; "Noted" dismisses it and persists the version.
//   2. A profile already current sees NO panel (show-once contract).
//   3. The Settings archive lists every entry, newest first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/news_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('stale profile sees the post once; Noted dismisses it', (
    tester,
  ) async {
    final c = GameController();
    c.meta.runsPlayed = 12; // a veteran, not a fresh install
    c.meta.lastSeenNewsVersion = '0.13.0';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    final panel = find.byKey(const ValueKey('news-panel'));
    await tester.scrollUntilVisible(panel, 80);
    expect(panel, findsOneWidget);
    final entry = newsFor(currentAppVersion)!;
    expect(
      find.descendant(
        of: panel,
        matching: find.text('THE HEARTHSIDE POST — v${entry.version}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text(entry.lines.first)),
      findsOneWidget,
    );

    // The title screen scrolls on short viewports (the 800x600 test surface
    // included) — bring the button into view before tapping, same as a player
    // scrolling. Assertions below are unchanged.
    await tester.ensureVisible(find.byKey(const ValueKey('news-dismiss')));
    await pumpFor(tester, 300);
    await tester.tap(find.byKey(const ValueKey('news-dismiss')));
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('news-panel')), findsNothing);
    expect(c.meta.lastSeenNewsVersion, currentAppVersion);
  });

  testWidgets('a current profile sees no panel at all', (tester) async {
    final c = GameController();
    c.meta.runsPlayed = 12;
    c.meta.lastSeenNewsVersion = currentAppVersion;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('news-panel')), findsNothing);
  });

  testWidgets('the archive lists every entry, newest first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: const NewsArchiveScreen()),
    );
    await tester.pump();
    for (final e in newsEntries) {
      final card = find.byKey(ValueKey('news-archive-${e.version}'));
      await tester.scrollUntilVisible(card, 120);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(e.title)),
        findsOneWidget,
      );
    }
  });
}
