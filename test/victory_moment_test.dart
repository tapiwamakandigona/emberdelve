// test/victory_moment_test.dart — experimental polish loop, critic round 4
// issue C4-01: the victory moment was a pile-up of text.
//
// Round-4 plates caught the run-ending kill as a word salad: "+5 EMBERS —
// EXACT!", then "VICTORY!" with the "-4" butted against it, STRAIGHT! /
// TRIPLE! / PAIR +2 under the banner and over the HP bar, and the burn chip
// (play_session 039 and 020). At 320x568 the banner also covered the
// delver's sword arm at +600 and +1200 ms (victory_320x568_t0600/t1200).
//
// This test lands a real run-ending blow through the production controls
// while the opening roll's call-outs are still up (seed 6 rolls a 3-4-5
// straight: STRAIGHT! and FREE REROLL NEXT TURN) and the foe is burning.
// FIXTURE, as in test/victory_beat_test.dart: the node and the foe are
// marked boss, the foe's HP is the chosen die (an EXACT kill, so
// "+N EMBERS — EXACT!" fires), no block, burn 3. At 320x568, 360x800 and
// 412x915, in normal and reduced motion, on every 40 ms frame to +1200 ms
// (+600 and +1200 included) it asserts:
//   • from the banner's first frame, no other visible text (opacity > 0.1)
//     intersects the banner;
//   • at +600, at +1200 and on every frame after the banner's intro, the
//     banner stays off the delver's box (figure and weapon), inside the
//     stage, at >= 22 sp (font size x every scale it is drawn at);
//   • from 150 ms (+ one frame) after the banner's first frame, no call-out
//     in either lane, damage number, help pill, status chip or intent badge
//     is visible (opacity > 0.1), and no text but the banner sits in the
//     stage: the moment reads "VICTORY!" plus the HUD numbers.
// 0.186.0 review: the same blow and checks run for every other playable
// delver at every size, and the delver's box lookup fails loudly when its
// figure or weapon key is missing instead of skipping the check.
// Nothing in lib/sim is touched.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/tour.dart';
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

import 'callout_lane_test.dart' show toFight;
import 'kill_readout_test.dart'
    show alphaOf, button, loadRealFonts, makeController, paintedRect;

/// The critic's visibility threshold.
const _visible = 0.1;

/// The other readouts get 150 ms to clear, plus one 40 ms frame.
const _clearMs = 150 + 40;

/// The banner's scale-in (VictoryBeat.intro).
const _introMs = 250;

/// [ro]'s box on screen with every transform applied (rotation included).
Rect _screenBox(RenderBox ro) =>
    MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);

Rect? _boxOfKey(WidgetTester tester, String key) {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) return null;
  return _screenBox(tester.renderObject(f.first) as RenderBox);
}

/// The delver's figure and its weapon, as one box. A rigged delver draws a
/// `figure-<id>` with its `hero-<id>` sprite and weapon inside; the others
/// draw a `hero-<id>` sprite with the weapon beside it. Fails the test when
/// the figure or the weapon is missing: a renamed key must not turn the
/// banner-vs-delver check into a silent pass.
Rect _heroBox(WidgetTester tester, String character) {
  final figure = _boxOfKey(tester, 'figure-$character');
  final sprite = _boxOfKey(tester, 'hero-$character');
  final weapon = _boxOfKey(tester, 'combat-weapon');
  if ((figure == null && sprite == null) || weapon == null) {
    fail(
      'no box for the delver $character: '
      'figure-$character ${figure == null ? 'missing' : 'found'}, '
      'hero-$character ${sprite == null ? 'missing' : 'found'}, '
      'combat-weapon ${weapon == null ? 'missing' : 'found'}',
    );
  }
  var out = weapon;
  if (figure != null) out = out.expandToInclude(figure);
  if (sprite != null) out = out.expandToInclude(sprite);
  return out;
}

bool _hits(Rect a, Rect b) {
  final o = a.intersect(b);
  return o.width > 1.0 && o.height > 1.0;
}

/// One visible text on screen and the readout it belongs to.
class _Text {
  final String kind; // note | pop | help | chip | badge | text
  final String label;
  final Rect rect;
  final double alpha;
  final RenderParagraph ro;
  _Text(this.kind, this.label, this.rect, this.alpha, this.ro);
  @override
  String toString() =>
      '$kind "$label" a=${alpha.toStringAsFixed(2)} ${_r(rect)}';
}

String _r(Rect r) =>
    '(${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)})';

List<_Text> _texts() {
  final badgeCtx = TourAnchors.of(TourBeats.intent).currentContext;
  final out = <_Text>[];
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    final text = ro.text.toPlainText().trim();
    if (text.isEmpty) continue;
    final a = alphaOf(e);
    if (a <= _visible) continue;
    var kind = 'text';
    e.visitAncestorElements((anc) {
      final w = anc.widget;
      if (w is TextPop) {
        kind = 'note';
      } else if (w is DamagePop) {
        kind = 'pop';
      } else if (w is HelpPill) {
        kind = 'help';
      } else if (w.runtimeType.toString() == '_StatusChip') {
        kind = 'chip';
      } else if (badgeCtx != null && identical(anc, badgeCtx)) {
        kind = 'badge';
      } else {
        return true;
      }
      return false;
    });
    out.add(_Text(kind, text, paintedRect(ro), a, ro));
  }
  return out;
}

/// Resting size of the banner: its font size times every scale between its
/// glyphs and the screen (FittedBox, intro scale-in).
double _bannerSp(WidgetTester tester, Finder banner) {
  final ro = tester.renderObject(banner) as RenderParagraph;
  final len = ro.text.toPlainText().length;
  final local = ro
      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: len))
      .map((b) => b.toRect())
      .reduce((a, b) => a.expandToInclude(b));
  final scale = paintedRect(ro).height / local.height;
  return (tester.widget<Text>(banner).style?.fontSize ?? 0) * scale;
}

Future<void> _victoryMoment(
  WidgetTester tester, {
  required Size size,
  required bool reduced,
  String character = 'kindler',
  bool requireCallouts = true,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: reduced ? 'on' : 'off');
  await tester.runAsync(warmSpriteSheets);
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  // Seed 6: the opening roll is a 3-4-5 straight (STRAIGHT! + FREE REROLL).
  await toFight(tester, c, 6, character: character);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 900; t += 40) {
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
  expect(die, greaterThan(0), reason: 'seed 6 must roll an attack die >= 2');

  // FIXTURE: the run-ending EXACT blow on a burning boss.
  final map = c.sim!.map!;
  ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
  c.sim!.enemy!['boss'] = true;
  c.sim!.enemy!['hp'] = value;
  c.sim!.enemy!['block'] = 0;
  c.sim!.enemy!['burn'] = 3;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();

  // The pile-up's ingredients are really on screen before the blow. Seed 6
  // rolls the straight with the kindler's dice; several other delvers'
  // dice roll no call-out there, so their cases don't require one.
  final before = _texts();
  if (requireCallouts) {
    expect(
      before.where((t) => t.kind == 'note'),
      isNotEmpty,
      reason: 'the opening roll\'s call-outs are up: $before',
    );
  }
  expect(
    before.where((t) => t.kind == 'chip'),
    isNotEmpty,
    reason: 'the burn chip shows: $before',
  );

  final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
  await tester.tap(dice.at(die - 1));
  await tester.pump();
  await tester.tap(button('Attack'));

  final tag =
      '${character == 'kindler' ? '' : '$character '}'
      '${size.width.toInt()}x${size.height.toInt()}'
      '${reduced ? ' reduced' : ''}';
  final problems = <String>[];
  int? first;
  var sawPop = false, checked = 0;
  for (var ms = 40; ms <= 1200; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    final banner = find.byKey(const ValueKey('victory-banner'));
    final texts = _texts();
    if (banner.evaluate().isEmpty) {
      if (texts.any((t) => t.kind == 'pop')) sawPop = true;
      if (ms >= 600) problems.add('$tag +$ms ms: no victory banner');
      continue;
    }
    first ??= ms;
    final bannerRo = tester.renderObject(banner) as RenderParagraph;
    final b = paintedRect(bannerRo);
    final others = texts.where((t) => !identical(t.ro, bannerRo)).toList();
    // Nothing visible is ever drawn across the banner.
    for (final t in others) {
      if (_hits(b, t.rect)) {
        problems.add('$tag +$ms ms: banner ${_r(b)} crosses $t');
      }
    }
    final stage = _boxOfKey(tester, 'victory-beat')!;
    // One word: the other readouts have cleared.
    if (ms - first >= _clearMs) {
      for (final t in others) {
        final inStage = stage.deflate(2).contains(t.rect.center);
        if (t.kind != 'text' || inStage) {
          problems.add('$tag +$ms ms: still visible $t');
        }
      }
    }
    // Size, stage and the delver, once the banner has landed.
    if (ms - first >= _introMs || ms == 600 || ms == 1200) {
      checked++;
      final hero = _heroBox(tester, character);
      if (_hits(b, hero)) {
        problems.add('$tag +$ms ms: banner ${_r(b)} on the delver ${_r(hero)}');
      }
      if (ms - first >= _introMs) {
        if (b.left < stage.left - 0.5 ||
            b.right > stage.right + 0.5 ||
            b.top < stage.top - 0.5 ||
            b.bottom > stage.bottom + 0.5) {
          problems.add(
            '$tag +$ms ms: banner ${_r(b)} leaves the stage '
            '${_r(stage)}',
          );
        }
        final sp = _bannerSp(tester, banner);
        if (sp < 22 - 0.05) {
          problems.add('$tag +$ms ms: banner at ${sp.toStringAsFixed(1)} sp');
        }
      }
    }
  }
  expect(first, isNotNull, reason: '$tag: the victory banner never showed');
  expect(sawPop, isTrue, reason: '$tag: the killing blow drew its number');
  expect(checked, greaterThanOrEqualTo(2));
  expect(c.phase, 'run_won', reason: 'the fixture blow ends the run');
  expect(problems, isEmpty, reason: problems.take(40).join('\n'));
  // Let the held phase switch and every timer run out.
  for (var t = 0; t < 4000; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRealFonts);

  for (final reduced in const [false, true]) {
    for (final size in const [Size(320, 568), Size(360, 800), Size(412, 915)]) {
      testWidgets(
        'victory at ${size.width.toInt()}x${size.height.toInt()}'
        '${reduced ? ' (reduced motion)' : ''}: one word, off the delver',
        (t) => _victoryMoment(t, size: size, reduced: reduced),
      );
    }
  }

  // 0.186.0 review: the banner's keep-out box (VictoryBeat.heroEnvelope) was
  // measured on the kindler only. The same blow, banner and checks for every
  // other playable delver, at every size, in normal and reduced motion.
  group('every delver', () {
    for (final character in charactersOrder.skip(1)) {
      for (final reduced in const [false, true]) {
        for (final size in const [
          Size(320, 568),
          Size(360, 800),
          Size(412, 915),
        ]) {
          testWidgets(
            '$character victory at '
            '${size.width.toInt()}x${size.height.toInt()}'
            '${reduced ? ' (reduced motion)' : ''}: off the delver',
            (t) => _victoryMoment(
              t,
              size: size,
              reduced: reduced,
              character: character,
              requireCallouts: false,
            ),
          );
        }
      }
    }
  });
}
