// test/readout_lanes_test.dart — experimental polish loop C0-03: the stage
// readout plan (lib/ui/readout_lanes.dart) is pure geometry, so its
// guarantees are pinned here across a sweep of stage shapes: every phone
// width, stage heights from the tightest rolled 320x568 stage (~86 px) to a
// tall 412x915 one, normal/elite bodies, narrow-to-wide sprites and larger
// text. test/kill_readout_test.dart checks the same promise on real kills.
//
// C1-02 (critic round 1): call-outs were squeezed to ~5 dp on a 320x568
// stage and printed across the hero's helmet. This file used to pin the
// planner with a hand-typed long call-out of 205x20 px — but the real
// "OVERKILL +3 → NEXT FOE" (+ icon, 15 sp Inter w800) measures 240x18, so
// the "every measured phone stage plans clean" check passed on a size the
// game no longer has while the 320x568 stage fell back to a 91 px slot
// (scale 0.37). The long call-out is now MEASURED with the shipped font, and
// every slot must (a) sit above both actors' heads and (b) take the long
// call-out at >= 12 sp ([ReadoutLanes.minNoteSp]). A stage with no room for
// that has no slots at all — its call-outs take the tray lane, which is
// pinned at the bottom of this file and on real screens by
// test/callout_lane_test.dart.
import 'dart:math' as math;

import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/readout_lanes.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' show loadRealFonts;

/// The 12 sp floor as a fit scale for the stage's 15 sp call-outs.
const floor = ReadoutLanes.minNoteSp / 15;

StageGeometry geometry({
  required double w,
  required double h,
  required double enemyH,
  required double heroH,
  required double aspect,
  required Size badge,
}) {
  final spriteW = enemyH * aspect;
  final lift = math.min(44.0, h - 8 - enemyH);
  return StageGeometry(
    stage: Size(w, h),
    enemyBody: Rect.fromLTWH(w - spriteW, h - 8 - enemyH, spriteW, enemyH),
    heroBody: Rect.fromLTWH(0, h - 8 - heroH, heroH * 0.62, heroH),
    badge: Rect.fromLTWH(
      w + 16 - badge.width,
      h - 8 - enemyH - lift,
      badge.width,
      badge.height,
    ),
  );
}

bool inside(Rect r, Size s) => r.top >= -0.5 && r.bottom <= s.height + 0.5;
bool apart(Rect a, Rect b) => !a.overlaps(b);
bool within(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

void main() {
  const pop = Size(50, 32); // "-88" at 26 sp
  // The longest stage call-out, measured with the shipped font in setUpAll
  // (it is 240x18; the old hand-typed 205x20 hid C1-02).
  var noteW = 0.0, noteH = 0.0;
  setUpAll(() async {
    await loadRealFonts();
    final long = TextPop.measure(
      'OVERKILL +3 → NEXT FOE',
      fontSize: 15,
      hasIcon: true,
    );
    noteW = long.width;
    noteH = long.height;
  });

  test('the long call-out is measured, not typed in', () {
    expect(noteW, greaterThan(220), reason: 'measured ${noteW}x$noteH');
    expect(noteH, inInclusiveRange(16, 24));
  });

  test('the sweep bound really bounds the painted motion', () {
    // Spot-check the sampled bound against dense frames for both widgets.
    const box = Size(60, 30);
    final dp = DamagePop.sweep(box);
    final tp = TextPop.sweep(box);
    for (var i = 0; i <= 1000; i++) {
      final f = i / 1000;
      final m = DamagePop.motion(f);
      if (m.alpha >= 0.05) {
        final gy = (m.scale - 1) * box.height / 2;
        expect(gy - m.offset.dy, lessThanOrEqualTo(dp.top + 0.35));
        expect(gy + m.offset.dy, lessThanOrEqualTo(dp.bottom + 0.35));
      }
      final n = TextPop.motion(f);
      if (n.alpha >= 0.05) {
        final gy = (n.scale - 1) * box.height / 2;
        expect(gy - n.offset.dy, lessThanOrEqualTo(tp.top + 0.35));
      }
    }
    // Defaults are the original motion (46 px arc, 34 px drift-up).
    expect(DamagePop.motion(1).offset.dy, closeTo(-46 + 18, 0.01));
    expect(TextPop.motion(1).offset.dy, closeTo(-34, 0.01));
  });

  // One test per phone width and body size; each sweeps stage heights,
  // sprite aspects and badge sizes and reports every broken promise.
  var shapes = 0, clean = 0;
  for (final w in const [272.0, 312.0, 364.0]) {
    for (final big in const [false, true]) {
      test(
        'plan invariants: stage width $w, ${big ? 'elite' : 'normal'} foe',
        () {
          final broken = <String>[];
          void check(bool ok, String what) {
            if (!ok) broken.add(what);
          }

          for (var h = 84.0; h <= 420; h += 6) {
            final compact = h < 200;
            final enemyH = compact ? (big ? 96.0 : 72.0) : (big ? 128.0 : 96.0);
            final heroH = compact ? 72.0 : 104.0;
            if (h < enemyH * 0.9) continue; // the stage never gets this short
            for (final aspect in const [0.8, 1.0, 1.4, 2.0]) {
              for (final badge in const [
                Size(106, 38),
                Size(128, 40),
                Size(154, 48),
              ]) {
                shapes++;
                final g = geometry(
                  w: w,
                  h: h,
                  enemyH: enemyH,
                  heroH: heroH,
                  aspect: aspect,
                  badge: badge,
                );
                final p = ReadoutLanes.plan(
                  g,
                  typicalPop: pop,
                  noteHeight: noteH,
                  typicalNoteWidth: noteW,
                  minNoteScale: floor,
                );
                if (!p.clean) continue;
                clean++;
                final tag = 'h=$h aspect=$aspect badge=$badge';
                final zone = p.enemyPopZone.swept;
                check(inside(zone, g.stage), '$tag zone leaves the stage');
                check(apart(zone, g.badge), '$tag zone/badge');
                // C1-02: every slot sits above both actors' heads.
                final heads = math.min(g.heroBody.top, g.enemyBody.top);
                for (final (i, s) in p.slots.indexed) {
                  check(
                    inside(s.swept, g.stage),
                    '$tag slot $i leaves the stage',
                  );
                  check(
                    s.swept.bottom <= heads,
                    '$tag slot $i reaches the actors (${s.swept} vs $heads)',
                  );
                  check(apart(s.swept, g.heroBody), '$tag slot $i/hero');
                  check(apart(s.swept, g.enemyBody), '$tag slot $i/foe');
                  // ...and takes the longest call-out at >= 12 sp.
                  final long = p.placeNote(i, Size(noteW, noteH));
                  check(
                    long != null && long.scale >= floor - 1e-9,
                    '$tag slot $i cannot take the long call-out at 12 sp',
                  );
                  check(apart(s.swept, g.badge), '$tag slot $i/badge');
                  check(apart(s.swept, zone), '$tag slot $i/zone');
                  for (final t in p.slots.skip(i + 1)) {
                    check(apart(s.swept, t.swept), '$tag slots overlap');
                  }
                  // Any call-out that takes the slot sweeps inside it and
                  // is never drawn under 12 sp (C1-02; it used to be any
                  // scale over 0.5, i.e. 7.5 sp). Short and long ones up to
                  // the measured longest always fit; a wider one (bigger
                  // text) either fits at >= 12 sp or is refused, and the
                  // screen gives it another lane.
                  for (final size in [
                    const Size(68, 18), // "BURN"
                    Size(noteW * 0.87, noteH), // "+5 EMBERS — EXACT!"
                    Size(noteW, noteH),
                    Size(noteW * 1.3, noteH * 1.3), // 1.3x text
                  ]) {
                    final n = p.placeNote(i, size);
                    if (n == null) {
                      check(
                        size.width > noteW,
                        '$tag note $size refused by slot $i',
                      );
                      continue;
                    }
                    check(
                      within(n.swept, s.swept),
                      '$tag note $size escapes slot $i',
                    );
                    check(
                      n.scale >= floor - 1e-9,
                      '$tag note $size under 12 sp (${n.scale})',
                    );
                  }
                }
                // Smaller numbers sweep inside the planned zone.
                for (final size in const [Size(26, 32), Size(50, 32)]) {
                  check(
                    within(p.placeEnemyPop(size).swept, zone),
                    '$tag number $size escapes the zone',
                  );
                }
                final hero = p.heroPopZone.swept;
                check(inside(hero, g.stage), '$tag hero zone leaves the stage');
                check(apart(hero, g.badge), '$tag hero/badge');
                check(apart(hero, zone), '$tag hero/zone');
                for (final s in p.slots) {
                  check(apart(hero, s.swept), '$tag hero/slot');
                }
              }
            }
          }
          expect(broken, isEmpty, reason: broken.take(10).join('\n'));
        },
      );
    }
  }

  test('almost every realistic stage gets a clean plan', () {
    // Runs after the sweeps above (tests run in declaration order). Only
    // the very shortest stages (a rolled 320x568 with an elite) may fall
    // back to best effort.
    expect(shapes, greaterThan(1000));
    expect(clean / shapes, greaterThan(0.9), reason: '$clean of $shapes');
  });

  test('every measured phone stage (seed-1 fight, rolled) plans clean', () {
    // Stage boxes measured from the real combat screen after ROLL.
    for (final (w, h, enemyH, heroH) in const [
      (272.0, 86.0, 72.0, 72.0), // 320x568
      (272.0, 158.0, 72.0, 72.0), // 320x640
      (312.0, 250.0, 96.0, 104.0), // 360x800
      (364.0, 365.0, 96.0, 104.0), // 412x915
    ]) {
      final g = geometry(
        w: w,
        h: h,
        enemyH: enemyH,
        heroH: heroH,
        aspect: 1.0,
        badge: const Size(106, 38), // the seed-1 foe's two-chip badge
      );
      final p = ReadoutLanes.plan(
        g,
        typicalPop: pop,
        noteHeight: noteH,
        typicalNoteWidth: noteW,
        minNoteScale: floor,
      );
      expect(p.clean, isTrue, reason: 'stage ${w}x$h');
      // C1-02: the long call-out is never drawn under 12 sp on any phone
      // (it used to be allowed down to 72%, and 320x568 actually got 37%).
      // The rolled 320x568 stage (86 px, both actors 72 px tall) has no room
      // above the heads, so it plans NO stage slot: its call-outs take the
      // tray lane. Every other measured phone keeps a stage slot.
      if (h < 100) {
        expect(p.slots, isEmpty, reason: 'stage ${w}x$h');
      } else {
        expect(p.slots, isNotEmpty, reason: 'stage ${w}x$h');
        expect(
          p.placeNote(0, Size(noteW, noteH))?.scale,
          greaterThanOrEqualTo(floor),
          reason: 'stage ${w}x$h',
        );
      }
      // Tall stages keep the full motion: the arc and the drift-up.
      if (h >= 250) {
        expect(p.enemyPopZone.rise, DamagePop.defaultRise);
        expect(p.slots.first.rise, TextPop.defaultRise);
        expect(p.slots.length, 2);
      }
    }
  });

  // C0-03 + C1-02: the tray lane — the strip between the player's HP bar and
  // the dice, beside the "YOUR HP" caption. On the tightest phone it is the
  // ONLY lane (no stage slot), so every real call-out must fit it at >= 12 sp
  // with its whole sweep inside the strip.
  test('the tray lane takes every real call-out at >= 12 sp, clear of the '
      'HP bar, the caption and the dice', () {
    final caption = (TextPainter(
      text: const TextSpan(text: 'YOUR HP', style: EmberText.micro),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout()).size;
    const trayFloor = ReadoutLanes.minNoteSp / 16;
    final broken = <String>[];
    for (final (width, compact) in const [
      (320.0, true), // 320x568 / 320x640
      (360.0, false), // 360x800
      (412.0, false), // 412x915
    ]) {
      final gapAbove = compact ? 8.0 : 16.0;
      final lane = TrayLane.measure(
        trayWidth: width - 32,
        gapAbove: gapAbove,
        caption: caption,
        barGap: 4,
        minNoteScale: trayFloor,
      );
      // The strip: under the bar, over the dice, right of the caption.
      final barBottom = -(gapAbove + caption.height + 4);
      if (lane.band.top < barBottom ||
          lane.band.bottom > 0 ||
          lane.band.left < caption.width) {
        broken.add('$width: band ${lane.band} vs bar $barBottom / caption');
      }
      for (final text in const [
        'STRAIGHT!',
        'FREE REROLL NEXT TURN',
        'ALREADY ASSIGNED',
        'PAIR +2',
        'RIPOSTE BLOCKED',
        '+5 EMBERS — EXACT!',
        'OVERKILL +3 → NEXT FOE',
      ]) {
        final size = TextPop.measure(text, fontSize: 16, hasIcon: true);
        final at = lane.place(size);
        if (at == null) {
          broken.add('$width: "$text" ($size) does not fit at 12 sp');
          continue;
        }
        if (at.scale < trayFloor - 1e-9) {
          broken.add('$width: "$text" at ${at.scale} < 12 sp');
        }
        if (!within(at.swept, lane.band)) {
          broken.add('$width: "$text" sweeps ${at.swept} out of ${lane.band}');
        }
      }
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });
}
