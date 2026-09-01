// test/kindled_tale_test.dart — THE KINDLED TALE (fx.dart SmolderIn):
//   1. The reveal is paint-only: the FULL tale text is in the tree (and
//      findable) from the first frame of the rest screen.
//   2. Settled state drops the mask entirely — after the sweep there is no
//      ShaderMask above the tale, so an idle hollow pays nothing.
//   3. Reduce-motion never masks at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/sim/autoplay.dart';
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

/// Walk to the rest hollow with the autoplay bot (same fixture as
/// hearth_tale_test.dart — seed 6 easy rests under the bot's policy).
GameController atRest({int seed = 6}) {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'rest' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  return c;
}

bool _taleMasked(WidgetTester tester) => find
    .ancestor(
      of: find.byKey(const ValueKey('hearth-tale')),
      matching: find.byType(ShaderMask),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('tale text is whole from frame one; mask drops when settled', (
    tester,
  ) async {
    final c = atRest();
    expect(c.phase, 'rest', reason: 'seed 6 walk must reach a hollow');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    // Catch the smolder mid-sweep.
    var masked = false;
    for (var t = 0; t < 1200; t += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byKey(const ValueKey('hearth-tale')).evaluate().isNotEmpty) {
        // The FULL text is present the moment the widget exists.
        final tale = tester.widget<Text>(
          find.byKey(const ValueKey('hearth-tale')),
        );
        expect(tale.data, isNotEmpty);
        expect(tale.data, startsWith('\u201C'));
        expect(tale.data, endsWith('\u201D'));
        masked = _taleMasked(tester);
        if (masked) break;
      }
    }
    expect(masked, isTrue, reason: 'sweep should be visible mid-flight');

    // After the sweep: mask gone, text identical.
    await pumpFor(tester, 1200);
    expect(_taleMasked(tester), isFalse, reason: 'settled drops the mask');
    expect(find.byKey(const ValueKey('hearth-tale')), findsOneWidget);
    await pumpFor(tester, 600);
  });

  testWidgets('boon rumor smolders in and settles mask-free', (tester) async {
    final c = atRest(); // seasoned meta; we only need a fresh boon phase
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: BoonScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 25));
    final line = find.byKey(const ValueKey('rumor-line'));
    expect(line, findsOneWidget);
    // Full text from frame one, even mid-sweep.
    expect(tester.widget<Text>(line).data, isNotEmpty);
    expect(
      find.ancestor(of: line, matching: find.byType(ShaderMask)),
      findsOneWidget,
      reason: 'the rumor smolders in',
    );
    for (var t = 0; t < 1000; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.ancestor(of: line, matching: find.byType(ShaderMask)),
      findsNothing,
      reason: 'settled rumor drops the mask',
    );
  });

  testWidgets('reduce-motion never masks', (tester) async {
    Motion.instance.update(setting: 'on');
    addTearDown(() => Motion.instance.update(setting: 'system'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Scaffold(
          body: SmolderIn(child: Text('tale', key: ValueKey('tale'))),
        ),
      ),
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('tale')),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
  });
}
