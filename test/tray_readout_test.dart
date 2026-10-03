// test/tray_readout_test.dart — experimental polish loop, critic round 1
// issue C0-03 (rescoped): the dice-tray combo call-outs must never stack on
// each other, and a surviving call-out must never JUMP when a sibling expires.
//
// Round-1 plates showed "FREE REROLL NEXT TURN" and "STRAIGHT!" overprinting
// each other over the tray, and a call-out sliding down into a freed slot the
// moment its neighbour faded. The tray lane used the LIVE list index for its
// vertical offset, so every note's position depended on how many other notes
// happened to be alive — they overlapped when close together and jumped when
// one expired.
//
// The fix gives each tray call-out a FIXED reserved slot for its whole life
// (the same mechanism the stage lane already uses), a small capped budget,
// and a stride of a full line-height between slots. This test forces a real
// straight — which emits BOTH "STRAIGHT!" and "FREE REROLL NEXT TURN" at once
// — through the production reroll control at three phone sizes, samples every
// 40 ms frame, and asserts:
//   • no two tray call-outs ever overlap each other, and
//   • no tray call-out ever jumps DOWN (its top only drifts up over its life).
//
// SCOPE: this pins the mutual-overlap + no-jump invariant only. Lifting the
// whole tray lane clear of the HP row AND the hero sprite needs the
// top-of-stage relocation the critic specs (a separate, owner-visible change);
// it is NOT asserted here. The dice pool is fixtured to a straight the same
// way kill_readout_test fixtures a lethal blow; no simulation rule is touched.
//
// The probe helpers mirror test/kill_readout_test.dart (kept local so that
// known-good test is left untouched).
import 'dart:io';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader('Cinzel')
        ..addFont(asset('assets/fonts/Cinzel-Variable.ttf')))
      .load();
  await (FontLoader('Inter')..addFont(asset('assets/fonts/Inter-Regular.ttf')))
      .load();
}

Finder button(String label) => find.byWidgetPredicate(
  (w) => w is EmberButton && w.label == label && w.onTap != null,
);

/// Product of every opacity between [e] and the root.
double alphaOf(Element e) {
  var a = 1.0;
  e.visitAncestorElements((anc) {
    final w = anc.widget;
    if (w is Opacity) a *= w.opacity;
    if (w is FadeTransition) a *= w.opacity.value;
    if (w is Offstage && w.offstage) a = 0;
    return a > 0.0;
  });
  return a;
}

/// Where the glyphs actually are, in global coordinates with every transform
/// applied (a Text inside an Expanded has a box far wider than its ink).
Rect paintedRect(RenderParagraph p) {
  final len = p.text.toPlainText().length;
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: len),
  );
  var local = Offset.zero & p.size;
  if (boxes.isNotEmpty) {
    local = boxes.map((b) => b.toRect()).reduce((a, b) => a.expandToInclude(b));
  }
  return MatrixUtils.transformRect(p.getTransformTo(null), local);
}

class NoteBox {
  final String text;
  final Rect rect;
  final RenderObject owner;
  NoteBox(this.text, this.rect, this.owner);
  @override
  String toString() => '"$text" $rect';
}

/// Every visible TRAY call-out (a TextPop) on screen right now.
List<NoteBox> visibleNotes(WidgetTester tester) {
  final out = <NoteBox>[];
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    if (alphaOf(e) < 0.05) continue;
    final text = ro.text.toPlainText().trim();
    if (text.isEmpty) continue;
    RenderObject? owner;
    e.visitAncestorElements((anc) {
      if (anc.widget is TextPop) {
        owner = anc.renderObject;
        return false;
      }
      return true;
    });
    if (owner != null) out.add(NoteBox(text, paintedRect(ro), owner!));
  }
  return out;
}

GameController makeController() {
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.tipDirector = TipDirector(c.meta.tipsSeen);
  c.meta.tourSeenVersion = tourVersion;
  c.tour = TourDirector(seenVersion: tourVersion);
  return c;
}

Future<void> toFight(WidgetTester tester, GameController c, {int seed = 1}) async {
  c.startRun(character: 'kindler', boons: true, seed: seed, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  for (var t = 0; t < 2600; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(c.phase, 'player_turn');
}

/// Seed 6's kindler opening roll is a 3-4-5 straight, which emits BOTH
/// "STRAIGHT!" and "FREE REROLL NEXT TURN" over the tray at once (the roll
/// path announces combos ~550 ms after the tumble). No pool fixture needed.
Future<void> openingStraight(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  Motion.instance.update(setting: 'off');
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c, seed: 6);
  await tester.tap(button('Roll'));
  // Past the tumble and the ~550 ms combo-announce delay.
  for (var ms = 0; ms < 900; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> trayCase(WidgetTester tester, {required Size size}) async {
  await openingStraight(tester, size: size);

  var sawTwoAtOnce = false;
  final firstTop = <RenderObject, double>{};
  final problems = <String>[];

  for (var ms = 0; ms <= 2200; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    final notes = visibleNotes(tester);
    if (notes.length >= 2) sawTwoAtOnce = true;

    // (a) no two tray call-outs overlap each other.
    for (var i = 0; i < notes.length; i++) {
      for (var j = i + 1; j < notes.length; j++) {
        if (identical(notes[i].owner, notes[j].owner)) continue;
        final o = notes[i].rect.intersect(notes[j].rect);
        if (o.width > 1.0 && o.height > 1.0) {
          problems.add('t=${ms}ms  stacked: ${notes[i]}  ×  ${notes[j]}');
        }
      }
    }
    // (b) no call-out ever jumps DOWN: a fixed slot means its top only ever
    // drifts up over its life, never slides into a freed lower slot.
    for (final n in notes) {
      final first = firstTop[n.owner];
      if (first == null) {
        firstTop[n.owner] = n.rect.top;
      } else if (n.rect.top > first + 2.0) {
        problems.add(
          't=${ms}ms  jumped down: "${n.text}" '
          'top ${n.rect.top.toStringAsFixed(1)} > first '
          '${first.toStringAsFixed(1)}',
        );
      }
    }
  }

  expect(
    sawTwoAtOnce,
    isTrue,
    reason: 'the straight must show STRAIGHT! and FREE REROLL together',
  );
  expect(problems, isEmpty, reason: problems.take(12).join('\n'));
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {
    '320x568': Size(320, 568),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final entry in sizes.entries) {
    testWidgets('tray call-outs never stack or jump at ${entry.key}', (t) async {
      await trayCase(t, size: entry.value);
    });
  }
}
