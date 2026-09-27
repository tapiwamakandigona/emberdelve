// test/kill_readout_test.dart — experimental polish loop, critic round 0
// issue C0-03: the kill moment's readout must never stack on itself.
//
// Round-0 plates showed "+5 EMBERS — EXACT!" printed over the damage number
// and the live intent badge (008), a damage number sitting on the shield
// badge of a foe already at 0 HP (016), and "OVERKILL +3 → NEXT FOE" printed
// over the enemy HP caption (021). This test lands real lethal blows (an
// exact kill and an overkill) through the production controls at four phone
// sizes, samples every 40 ms frame of the kill choreography, and asserts:
//   • no call-out, damage number or intent badge overlaps any other visible
//     text on screen, and none of them overlaps each other;
//   • a foe at 0 HP shows no intent badge once the blow has landed;
//   • the damage number lives its one 650 ms life (never restarted).
// The foe's HP is set as a FIXTURE so the chosen die is exactly lethal (or
// one point over); nothing about the sim's rules is touched.
import 'dart:io';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/assignment.dart';
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
  await (FontLoader(
    'Cinzel',
  )..addFont(asset('assets/fonts/Cinzel-Variable.ttf'))).load();
  await (FontLoader(
    'Inter',
  )..addFont(asset('assets/fonts/Inter-Regular.ttf'))).load();
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

/// Where the glyphs actually are (a Text inside an Expanded has a box far
/// wider than its ink), in global coordinates with every transform applied.
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

class Box {
  final String kind; // note | pop | badge | text
  final String label;
  final Rect rect;
  final RenderObject owner;
  Box(this.kind, this.label, this.rect, this.owner);
  @override
  String toString() => '$kind "$label" $rect';
}

/// Every visible text on screen, tagged by the readout piece it belongs to.
List<Box> visibleTexts(WidgetTester tester) {
  final badgeCtx = TourAnchors.of(TourBeats.intent).currentContext;
  final out = <Box>[];
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    if (alphaOf(e) < 0.05) continue;
    final text = ro.text.toPlainText().trim();
    if (text.isEmpty) continue;
    var kind = 'text';
    RenderObject owner = ro;
    e.visitAncestorElements((anc) {
      final w = anc.widget;
      if (w is TextPop) {
        kind = 'note';
        owner = anc.renderObject!;
        return false;
      }
      if (w is DamagePop) {
        kind = 'pop';
        owner = anc.renderObject!;
        return false;
      }
      if (badgeCtx != null && identical(anc, badgeCtx)) {
        kind = 'badge';
        owner = anc.renderObject!;
        return false;
      }
      return true;
    });
    out.add(Box(kind, text, paintedRect(ro), owner));
  }
  return out;
}

/// Overlapping pairs where at least one side is kill-readout (note, pop or
/// badge) and the two are not parts of the same readout widget.
List<String> collisions(List<Box> boxes) {
  final hits = <String>[];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final a = boxes[i], b = boxes[j];
      if (a.kind == 'text' && b.kind == 'text') continue;
      if (identical(a.owner, b.owner)) continue;
      final o = a.rect.intersect(b.rect);
      if (o.width > 1.0 && o.height > 1.0) hits.add('$a  ×  $b');
    }
  }
  return hits;
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

Future<void> toFight(WidgetTester tester, GameController c) async {
  c.startRun(character: 'kindler', boons: true, seed: 1, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  for (var t = 0; t < 2600; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(c.phase, 'player_turn');
}

Future<void> killCase(
  WidgetTester tester, {
  required Size size,
  required bool exact,
}) async {
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
  await toFight(tester, c);
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
  expect(die, greaterThan(0), reason: 'seed 1 must roll an attack die ≥ 2');
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

  var sawPop = false, sawNote = false;
  int? landedAt;
  final problems = <String>[];
  for (var ms = 40; ms <= 2600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    if (c.phase != 'player_turn' &&
        find.byType(CombatScreen).evaluate().isEmpty) {
      break; // the fight is over and the screen moved on
    }
    final boxes = visibleTexts(tester);
    if (boxes.any((b) => b.kind == 'pop')) {
      sawPop = true;
      landedAt ??= ms;
      // One number, one 650 ms life. Inserting the kill's call-out used to
      // re-match the unkeyed overlay children by index and restart the
      // number (and the slash) mid-flight — it lived past 1 s.
      if (ms > landedAt + DamagePop.life.inMilliseconds + 80) {
        problems.add('t=${ms}ms  the damage number restarted (still showing)');
      }
    }
    if (boxes.any((b) => b.kind == 'note')) sawNote = true;
    for (final hit in collisions(boxes)) {
      problems.add('t=${ms}ms  $hit');
    }
    // A foe at 0 HP has no next move: its badge is gone shortly after the
    // blow lands (one short fade).
    if (landedAt != null && ms >= landedAt + 240) {
      final badge = boxes.where((b) => b.kind == 'badge').toList();
      if (badge.isNotEmpty) {
        problems.add('t=${ms}ms  dead foe still shows its badge: $badge');
      }
    }
  }
  expect(sawPop, isTrue, reason: 'the lethal blow shows its damage number');
  expect(sawNote, isTrue, reason: 'the kill shows its EXACT/OVERKILL call-out');
  expect(problems, isEmpty, reason: problems.take(12).join('\n'));
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {
    '320x568': Size(320, 568),
    '320x640': Size(320, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final entry in sizes.entries) {
    testWidgets('exact kill readout never stacks at ${entry.key}', (t) async {
      await killCase(t, size: entry.value, exact: true);
    });
    testWidgets('overkill readout never stacks at ${entry.key}', (t) async {
      await killCase(t, size: entry.value, exact: false);
    });
  }
}
