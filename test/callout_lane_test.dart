// test/callout_lane_test.dart — experimental polish loop, critic round 1
// issue C1-02 (with the C0-03 lane rule): on short stages call-outs were
// shrunk to ~5 dp and drawn over the hero sprite.
//
// Round-1 plates (kill_readout exact_320x568_t720/t1200, overkill_320x568_
// t960) caught "+5 EMBERS — EXACT!" and "OVERKILL +1 → NEXT FOE" squeezed to
// ~5 dp across the hero's helmet. The cause: the rolled 320x568 stage is
// 86 px with both actors standing 72 px tall, the planner found no slot for
// the real 240 px call-out, and its fallback slot (91 px) scaled it to 0.37
// with no floor. The kill_readout test passed because text-over-sprite was
// not counted and shrinking was allowed.
//
// This test lands real lethal blows (exact and overkill) on three different
// foes through the production controls at four phone sizes and samples every
// 40 ms frame of the kill. For every visible call-out it asserts:
//   • its resting size is >= 12 sp (font size x the fit scale it is drawn
//     at — the pop-in animation is motion, not size);
//   • its glyphs do not intersect the hero's or the foe's sprite box;
//   • it overlaps no other visible text (HP numerals and captions included).
// It also long-presses the burn chip on the tightest phone: the explanation
// must read at >= 12 sp, whole (no ellipsis). The foe's HP and burn are
// FIXTURES (as in test/kill_readout_test.dart); no simulation rule is
// touched.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart'
    show
        alphaOf,
        button,
        collisions,
        loadRealFonts,
        makeController,
        paintedRect,
        visibleTexts;

const minSp = 12.0;

/// One visible call-out: its glyphs on screen and its resting size in sp.
class Callout {
  final String text;
  final Rect rect;
  final double sp;
  final Element element;
  Callout(this.text, this.rect, this.sp, this.element);
  @override
  String toString() => '"$text" ${sp.toStringAsFixed(1)} sp $rect';
}

/// Every call-out (a [TextPop]) with visible glyphs. Its resting size is
/// the font size times the scale of the FittedBox it is drawn in (if any),
/// which is how both lanes fit a call-out to its slot.
List<Callout> visibleCallouts() {
  final out = <Callout>[];
  for (final e in find.byType(TextPop).evaluate()) {
    final pop = e.widget as TextPop;
    final natural = (e.renderObject as RenderBox?)?.size;
    var fit = 1.0;
    e.visitAncestorElements((anc) {
      final w = anc.widget;
      if (w is FittedBox) {
        final box = anc.renderObject as RenderBox;
        if (natural != null && natural.width > 0) {
          fit = box.size.width / natural.width;
        }
        return false;
      }
      return w is! Positioned; // the slot's Positioned ends the search
    });
    Rect? ink;
    for (final t
        in find
            .descendant(
              of: find.byElementPredicate((x) => identical(x, e)),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final ro = t.renderObject;
      if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
      if (ro.size.isEmpty || alphaOf(t) < 0.05) continue;
      if (ro.text.toPlainText().trim().isEmpty) continue;
      final r = paintedRect(ro);
      ink = ink == null ? r : ink.expandToInclude(r);
    }
    if (ink != null) out.add(Callout(pop.text, ink, pop.fontSize * fit, e));
  }
  return out;
}

/// The delver's sprite box on screen (plain sheet or articulated rig).
Rect? heroRect(WidgetTester tester) {
  for (final key in const ['hero-kindler', 'figure-kindler']) {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isNotEmpty) return tester.getRect(f.first);
  }
  return null;
}

/// The foe's sprite box on screen, while it has one.
Rect? foeRect(WidgetTester tester) {
  final f = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('enemy-');
  });
  if (f.evaluate().isEmpty) return null;
  return tester.getRect(f.first);
}

bool hits(Rect a, Rect b) {
  final o = a.intersect(b);
  return o.width > 1.0 && o.height > 1.0;
}

/// Into the first fight of [seed] (node 2), as the kill harness does.
Future<void> toFight(WidgetTester tester, GameController c, int seed) async {
  c.startRun(character: 'kindler', boons: true, seed: seed, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  for (var t = 0; t < 2600; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(c.phase, 'player_turn');
}

/// Three foes of different builds (the C0-03 acceptance asks for three).
const foes = {1: 'flue_crawler', 2: 'cinder_pup', 4: 'slag_snail'};

Future<void> boot(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: 'off');
  await tester.runAsync(warmSpriteSheets);
}

Future<void> killCase(
  WidgetTester tester, {
  required Size size,
  required bool exact,
  required int seed,
}) async {
  await boot(tester, size);
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c, seed);
  expect(c.sim!.enemy!['id'], foes[seed]);
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
  expect(die, greaterThan(0), reason: 'seed $seed must roll an attack die ≥ 2');
  // FIXTURE: make the chosen die exactly lethal, or lethal with surplus.
  c.sim!.enemy!['hp'] = exact ? value : value - 1;
  c.sim!.enemy!['block'] = 0;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
  await tester.tap(dice.at(die - 1));
  await tester.pump();
  await tester.tap(button('Attack'));

  final kill = exact ? 'EXACT!' : 'NEXT FOE';
  var sawKill = false;
  final problems = <String>[];
  for (var ms = 40; ms <= 2600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    if (find.byType(CombatScreen).evaluate().isEmpty) break;
    final hero = heroRect(tester), foe = foeRect(tester);
    for (final n in visibleCallouts()) {
      if (n.text.contains(kill)) sawKill = true;
      if (n.sp < minSp - 0.01) problems.add('t=${ms}ms  under 12 sp: $n');
      if (hero != null && hits(n.rect, hero)) {
        problems.add('t=${ms}ms  on the hero $hero: $n');
      }
      if (foe != null && hits(n.rect, foe)) {
        problems.add('t=${ms}ms  on the foe $foe: $n');
      }
    }
    for (final hit in collisions(visibleTexts(tester))) {
      problems.add('t=${ms}ms  $hit');
    }
  }
  expect(sawKill, isTrue, reason: 'the kill must show its "$kill" call-out');
  expect(problems, isEmpty, reason: problems.take(12).join('\n'));
}

/// The effective size (sp) of the paragraph showing [needle]: its font size
/// times every scale between it and the screen (a squeezed call-out reads
/// small even though its font size is 15).
({double sp, bool clipped})? explanationSize(String needle) {
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    final text = ro.text.toPlainText();
    if (!text.contains(needle) || alphaOf(e) < 0.05) continue;
    final boxes = ro.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final local = boxes
        .map((b) => b.toRect())
        .reduce((a, b) => a.expandToInclude(b));
    final global = paintedRect(ro);
    final scale = global.height / local.height;
    double? font;
    ro.text.visitChildren((span) {
      if (span is TextSpan && span.style?.fontSize != null) {
        font = span.style!.fontSize;
        return false;
      }
      return true;
    });
    return (sp: (font ?? 14) * scale, clipped: ro.didExceedMaxLines);
  }
  return null;
}

Future<void> explainCase(WidgetTester tester, {required Size size}) async {
  await boot(tester, size);
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c, 1);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  // FIXTURE: give the foe burn so its status chip shows.
  c.sim!.enemy!['burn'] = 3;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  for (var t = 0; t < 400; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final chip = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_StatusChip',
  );
  expect(chip, findsOneWidget);
  await tester.longPress(chip);
  var seen = false;
  final problems = <String>[];
  for (var ms = 40; ms <= 1600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    // Past the first 400 ms any pop-in has settled: judge the resting size.
    if (ms < 400) continue;
    final s = explanationSize('BURN 3');
    if (s == null) continue;
    seen = true;
    if (s.sp < minSp - 0.01) {
      problems.add('t=${ms}ms  explanation at ${s.sp.toStringAsFixed(1)} sp');
    }
    if (s.clipped) problems.add('t=${ms}ms  explanation cut off');
  }
  expect(seen, isTrue, reason: 'long-press must explain the burn');
  expect(problems, isEmpty, reason: problems.take(8).join('\n'));
  for (var t = 0; t < 2400; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {
    '320x568': Size(320, 568),
    '320x640': Size(320, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final MapEntry(key: seed, value: foe) in foes.entries) {
    for (final entry in sizes.entries) {
      testWidgets('exact-kill call-out reads at >= 12 sp, off the sprites, '
          'at ${entry.key} ($foe)', (t) async {
        await killCase(t, size: entry.value, exact: true, seed: seed);
      });
      testWidgets('overkill call-out reads at >= 12 sp, off the sprites, '
          'at ${entry.key} ($foe)', (t) async {
        await killCase(t, size: entry.value, exact: false, seed: seed);
      });
    }
  }
  testWidgets('a long-press explanation reads whole at >= 12 sp at 320x568', (
    t,
  ) async {
    await explainCase(t, size: const Size(320, 568));
  });
}
