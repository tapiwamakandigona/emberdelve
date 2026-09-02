// test/paired_copies_test.dart — v0.180.0 The Paired Copies.
//
// The summary's copy-as-text offers (delve story + one of daily / weekly /
// seed challenge) share one row instead of stacking full-width. Pins: the
// pair sits on one line at 320 px with 1.3× text (real fonts), each label is
// a single unwrapped line, TalkBack still hears the full sentence, and a
// lone offer keeps its full-width, full-label form.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<GameController> playOut(WidgetTester tester, int seed) async {
  final c = GameController();
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  c.startRun(character: 'kindler', seed: seed, boons: true, difficulty: 'easy');
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect({'run_won', 'run_lost'}.contains(c.phase), isTrue);
  await pumpFor(tester, 2500);
  return c;
}

/// The label paragraph under [key]: one line, no horizontal overflow.
void expectOneLine(WidgetTester tester, Key key) {
  final text = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Text),
  );
  final para = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(para.size.width, greaterThanOrEqualTo(para.textSize.width - 0.5));
  final lines = para.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: para.text.toPlainText().length),
  );
  final tops = lines.map((b) => b.top.round()).toSet();
  expect(tops.length, 1, reason: 'label wrapped: ${para.text.toPlainText()}');
}

void main() {
  setUpAll(loadRealFonts);

  for (final scale in [1.0, 1.3]) {
    testWidgets('story and seed share one row at 320 px, $scale× text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await playOut(tester, 1);
      const story = ValueKey('copy-delve-story');
      const seed = ValueKey('copy-seed-challenge');
      await tester.scrollUntilVisible(find.byKey(seed), -200);
      await tester.pump();
      expect(find.byKey(story), findsOneWidget);
      expect(find.byKey(seed), findsOneWidget);
      final a = tester.getRect(find.byKey(story));
      final b = tester.getRect(find.byKey(seed));
      expect(a.top, b.top, reason: 'paired offers share one row');
      expect(a.height, b.height);
      expect(a.right, lessThanOrEqualTo(b.left));
      expectOneLine(tester, story);
      expectOneLine(tester, seed);
      // Short words on the buttons, full sentences for TalkBack.
      expect(
        find.descendant(of: find.byKey(story), matching: find.text('Story')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(seed), matching: find.text('Seed')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('copy-caption')), findsOneWidget);
      expect(find.bySemanticsLabel('Copy delve story'), findsOneWidget);
      expect(find.bySemanticsLabel('Copy seed challenge'), findsOneWidget);
      // The daily / weekly copies stay quiet on a normal run.
      expect(find.byKey(const ValueKey('copy-daily-result')), findsNothing);
      expect(find.byKey(const ValueKey('copy-weekly-result')), findsNothing);
    });
  }

  testWidgets('a paired copy still copies its full text', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    final c = await playOut(tester, 1);
    const seed = ValueKey('copy-seed-challenge');
    await tester.scrollUntilVisible(find.byKey(seed), -200);
    await tester.tap(find.byKey(seed));
    await tester.pump();
    expect(copied, [c.seedChallengeShareText]);
  });
}
