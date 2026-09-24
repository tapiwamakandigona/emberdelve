// test/readout_lanes_test.dart — experimental polish loop C0-03: the stage
// readout plan (lib/ui/readout_lanes.dart) is pure geometry, so its
// guarantees are pinned here across a sweep of stage shapes: every phone
// width, stage heights from the tightest rolled 320x568 stage (~86 px) to a
// tall 412x915 one, normal/elite bodies, narrow-to-wide sprites and larger
// text. test/kill_readout_test.dart checks the same promise on real kills.
import 'dart:math' as math;

import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/readout_lanes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const noteH = 20.0, noteW = 205.0; // "OVERKILL +3 → NEXT FOE" + icon, 15 sp

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
                );
                if (!p.clean) continue;
                clean++;
                final tag = 'h=$h aspect=$aspect badge=$badge';
                final zone = p.enemyPopZone.swept;
                check(inside(zone, g.stage), '$tag zone leaves the stage');
                check(apart(zone, g.badge), '$tag zone/badge');
                for (final (i, s) in p.slots.indexed) {
                  check(
                    inside(s.swept, g.stage),
                    '$tag slot $i leaves the stage',
                  );
                  check(apart(s.swept, g.badge), '$tag slot $i/badge');
                  check(apart(s.swept, zone), '$tag slot $i/zone');
                  for (final t in p.slots.skip(i + 1)) {
                    check(apart(s.swept, t.swept), '$tag slots overlap');
                  }
                  // Any call-out, short or long, sweeps inside its slot.
                  for (final size in const [
                    Size(70, 18),
                    Size(205, 20),
                    Size(260, 24),
                  ]) {
                    final n = p.placeNote(i, size);
                    check(
                      within(n.swept, s.swept),
                      '$tag note $size escapes slot $i',
                    );
                    check(n.scale > 0.5, '$tag note $size unreadable');
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
      );
      expect(p.clean, isTrue, reason: 'stage ${w}x$h');
      // A long call-out stays readable (>= 72% size) on every phone.
      expect(
        p.placeNote(0, const Size(noteW, noteH)).scale,
        greaterThanOrEqualTo(0.72),
        reason: 'stage ${w}x$h',
      );
      // Tall stages keep the full motion: the arc and the drift-up.
      if (h >= 250) {
        expect(p.enemyPopZone.rise, DamagePop.defaultRise);
        expect(p.slots.first.rise, TextPop.defaultRise);
        expect(p.slots.length, 2);
      }
    }
  });
}
