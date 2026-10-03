// test/tray_readout_test.dart — experimental polish loop, critic rounds 1+4
// issue C0-03 (with C1-02): the dice call-outs must never stack on each
// other, jump, get lost, shrink under 12 sp, or print over the HP row or a
// sprite.
//
// Round-1 plates: "FREE REROLL NEXT TURN" ran across the hero's feet, the
// foe ring and the burn chip; "STRAIGHT!" sat on the HP bar next to
// "21 / 30"; call-outs overprinted each other and slid into a freed slot
// when a sibling faded.
//
// HISTORY (independent review of 7ef6aed): the first version of this test
// (PR #121) was NOT red on the code it claimed to fix — seed 6 fires both
// straight call-outs in the same frame, so they expire together and nothing
// can jump, and its "two at once" guard counted text runs (an icon is a run
// of its own), so one call-out satisfied it. The review also found that
// #121's cap-of-2 "oldest yields" rule evicted a third call-out in the
// frame it was created. This version stages the case those rules break:
//
//   ROLL (seed 6's opening roll is a 3-4-5 straight: STRAIGHT! and FREE
//   REROLL NEXT TURN at once) → while they show, spend a die on Attack and
//   tap that spent die again → ALREADY ASSIGNED, a THIRD call-out that
//   outlives the first two.
//
// Sampled every 20 ms from the ROLL tap, at three phone sizes:
//   • no two call-outs overlap; none jumps (its centre never moves sideways
//     or down — a TextPop only rises);
//   • every call-out rests at >= 12 sp and overlaps no other visible text
//     (the HP numerals, the HP caption and the die labels included) and
//     neither sprite box;
//   • nothing is lost: each of the three is fully visible for >= 900 ms;
//   • where the screen has room (360x800, 412x915) the two straight
//     call-outs show TOGETHER. The rolled 320x568 screen has no room for two
//     at >= 12 sp anywhere clear of the HP row and the sprites (the stage is
//     86 px with both actors 72 px tall), so there they play one after
//     another — the critic's own alternative ("or queue them").
// No pool fixture and no simulation rule: seed 6's real opening roll.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/fx.dart' show ShakeBox;
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'callout_lane_test.dart'
    show Callout, foeRect, heroRect, hits, minSp, visibleCallouts;
import 'kill_readout_test.dart'
    show button, collisions, loadRealFonts, makeController, visibleTexts;

Future<void> toFight(WidgetTester tester, GameController c, int seed) async {
  c.startRun(character: 'kindler', boons: true, seed: seed, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  for (var t = 0; t < 2600; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(c.phase, 'player_turn');
}

const straight = 'STRAIGHT!', reroll = 'FREE REROLL NEXT TURN';
const spent = 'ALREADY ASSIGNED';

Future<void> trayCase(
  WidgetTester tester, {
  required Size size,
  required bool together,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: 'off');
  await tester.runAsync(warmSpriteSheets);
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c, 6);
  await tester.tap(button('Roll'));

  final problems = <String>[];
  final shown = <String, int>{}; // ms fully visible, per text
  final last = <Element, Offset>{}; // previous centre, per call-out
  var sawTogether = false, tapped = false;
  int? straightAt;

  for (var ms = 20; ms <= 5200; ms += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    final notes = visibleCallouts();
    final texts = {for (final n in notes) n.text};
    if (texts.contains(straight)) straightAt ??= ms;
    final live = {for (final n in notes) n.element};
    if (live.length >= 2 &&
        notes.any((n) => n.text == straight) &&
        notes.any((n) => n.text == reroll)) {
      sawTogether = true;
    }
    // 400 ms into the straight, spend a die and tap it again: a third,
    // later call-out that outlives the first two.
    if (!tapped && straightAt != null && ms >= straightAt + 400) {
      tapped = true;
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      await tester.tap(dice.first);
      await tester.pump();
      await tester.tap(button('Attack'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(dice.first, warnIfMissed: false);
    }

    final hero = heroRect(tester), foe = foeRect(tester);
    for (final n in notes) {
      if (n.sp < minSp - 0.01) problems.add('t=${ms}ms  under 12 sp: $n');
      if (hero != null && hits(n.rect, hero)) {
        problems.add('t=${ms}ms  on the hero $hero: $n');
      }
      if (foe != null && hits(n.rect, foe)) {
        problems.add('t=${ms}ms  on the foe $foe: $n');
      }
      // No jump: a call-out only ever rises in place — measured in its own
      // lane, so the stage's impact shake (a translate of the whole stage,
      // actors included) is not mistaken for a slot change.
      final c0 = last[n.element];
      final c1 = n.rect.center - (_inStage(n) ? _shake(tester) : Offset.zero);
      if (c0 != null && ((c1.dx - c0.dx).abs() > 1.5 || c1.dy - c0.dy > 1.5)) {
        problems.add('t=${ms}ms  jumped $c0 -> $c1: $n');
      }
      last[n.element] = c1;
      if (_fullyVisible(n)) shown[n.text] = (shown[n.text] ?? 0) + 20;
    }
    for (var i = 0; i < notes.length; i++) {
      for (var j = i + 1; j < notes.length; j++) {
        if (identical(notes[i].element, notes[j].element)) continue;
        if (hits(notes[i].rect, notes[j].rect)) {
          problems.add('t=${ms}ms  stacked: ${notes[i]}  ×  ${notes[j]}');
        }
      }
    }
    // Against every other visible text: HP numerals, HP caption, dice.
    for (final hit in collisions(visibleTexts(tester))) {
      problems.add('t=${ms}ms  $hit');
    }
    last.removeWhere((e, _) => !live.contains(e));
  }

  expect(straightAt, isNotNull, reason: 'seed 6 must roll its straight');
  expect(tapped, isTrue);
  for (final text in const [straight, reroll, spent]) {
    expect(
      shown[text] ?? 0,
      greaterThanOrEqualTo(900),
      reason: '"$text" must be readable for 900 ms (shown: $shown)',
    );
  }
  if (together) {
    expect(
      sawTogether,
      isTrue,
      reason: 'with room, STRAIGHT! and FREE REROLL show together',
    );
  }
  expect(problems, isEmpty, reason: problems.take(12).join('\n'));
}

/// Whether [n] is drawn inside the stage (which shakes on impact).
bool _inStage(Callout n) {
  var inside = false;
  n.element.visitAncestorElements((anc) {
    if (anc.widget is ShakeBox) inside = true;
    return !inside;
  });
  return inside;
}

/// The stage's current shake translation (zero at rest).
Offset _shake(WidgetTester tester) {
  final f = find.byType(ShakeBox);
  if (f.evaluate().isEmpty) return Offset.zero;
  final box = tester.renderObject(f.first);
  if (box is! RenderProxyBox || box.child == null) return Offset.zero;
  return box.child!.localToGlobal(Offset.zero) - box.localToGlobal(Offset.zero);
}

/// Fully visible: opaque, past its pop-in (the alpha fade is the life's
/// last 35%, after the 900 ms this test asks for).
bool _fullyVisible(Callout n) {
  var a = 1.0;
  n.element.visitAncestorElements((anc) {
    final w = anc.widget;
    if (w is Opacity) a *= w.opacity;
    return a > 0;
  });
  for (final e
      in find
          .descendant(
            of: find.byElementPredicate((x) => identical(x, n.element)),
            matching: find.byType(Opacity),
          )
          .evaluate()) {
    a *= (e.widget as Opacity).opacity;
  }
  return a >= 0.9;
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {
    '320x568': (Size(320, 568), false),
    '360x800': (Size(360, 800), true),
    '412x915': (Size(412, 915), true),
  };
  for (final entry in sizes.entries) {
    testWidgets('dice call-outs never stack, jump, shrink or get lost, and '
        'stay off the HP row and the sprites at ${entry.key}', (t) async {
      await trayCase(t, size: entry.value.$1, together: entry.value.$2);
    });
  }
}
