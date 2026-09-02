// test/quiet_shell_test.dart — v0.180.0 The Quiet Shell.
//
// Three repaint leaks found by tool/summary_probe_test.dart, pinned here by
// behavior rather than by absolute paint counts (which drift with content):
//   1. A toast (showFlash) must not repaint anything but itself — the
//      Scaffold body is boxed, so a settled summary under a "Healed 4" toast
//      paints no paragraph except the toast's own.
//   2. The phase veil (fade-through-black) must not repaint the screen it
//      covers — PhaseSwitcher keeps the screen and the veil in permanent
//      boundaries.
//   3. The Settling Count's digits must not relayout the ledger — the number
//      sits in a tight box (its final size) inside its own boundary.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Paragraph texts (and any background image, as 'IMAGE') painted while
/// [body] runs.
Future<List<String>> paintedParagraphs(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final out = <String>[];
  debugOnProfilePaint = (ro) {
    if (ro is RenderParagraph) out.add(ro.text.toPlainText());
    if (ro is RenderImage) out.add('IMAGE');
  };
  try {
    await body();
  } finally {
    debugOnProfilePaint = null;
  }
  return out;
}

void main() {
  testWidgets('a toast repaints no paragraph but its own', (tester) async {
    // The loss summary: dozens of paragraphs under one Scaffold body.
    final c = GameController();
    c.markTutorialSeen();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await pumpFrames(tester, 20);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_lost' && c.phase != 'run_won') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'run_lost');
    await pumpFrames(tester, 260); // entrance choreography fully settled
    final quiet = await paintedParagraphs(tester, () => pumpFrames(tester, 20));
    expect(quiet, isEmpty, reason: 'a settled summary paints no text/image');
    final during = await paintedParagraphs(tester, () async {
      c.announce('Healed 4');
      await pumpFrames(tester, 30);
    });
    expect(during, isNotEmpty, reason: 'the toast itself paints');
    expect(
      during.where((t) => t != 'Healed 4'),
      isEmpty,
      reason: 'nothing under the toast repaints: $during',
    );
  });

  testWidgets('the phase veil never repaints the screen beneath it', (
    tester,
  ) async {
    var key = 'a';
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return PhaseSwitcher(
              phaseKey: key,
              child: Center(child: Text('screen $key')),
            );
          },
        ),
      ),
    );
    set(() => key = 'b');
    await tester.pump();
    // Past the midpoint the new screen is mounted and the veil is lifting.
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('screen b'), findsOneWidget);
    final painted = await paintedParagraphs(
      tester,
      () => pumpFrames(tester, 4),
    );
    expect(
      painted,
      isEmpty,
      reason: 'the lifting veil must not re-rasterize the screen: $painted',
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the settling count sits in a tight box of its final size', (
    tester,
  ) async {
    final c = GameController();
    c.markTutorialSeen();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await pumpFrames(tester, 20);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_lost' && c.phase != 'run_won') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'run_lost');
    await pumpFrames(tester, 150);
    final count = find.byKey(const ValueKey('settling-count'));
    expect(count, findsOneWidget);
    final box = tester.widget<SizedBox>(
      find.ancestor(of: count, matching: find.byType(SizedBox)).first,
    );
    expect(box.width, isNotNull);
    expect(box.height, isNotNull);
    expect(
      find.ancestor(of: count, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    // The box is exactly the resting number's size — no wider, so the row
    // reads as it always did once settled.
    await pumpFrames(tester, 60);
    final text = tester.widget<Text>(
      find.descendant(of: count, matching: find.byType(Text)),
    );
    final run = c.sim!.run!;
    expect(text.data, '${run['embers']}');
    final para = tester.renderObject<RenderParagraph>(
      find.descendant(of: count, matching: find.byType(RichText)),
    );
    expect((para.size.width - box.width!).abs(), lessThan(0.5));
    // No changing frame relaid the ledger: the static rows never repaint.
    // (Re-run the count by remounting is not possible; the paragraph pin
    // above is the structural guarantee.)
  });
}
