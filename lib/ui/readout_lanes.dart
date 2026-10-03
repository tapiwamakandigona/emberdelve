// lib/ui/readout_lanes.dart — experimental polish loop, critic round 0
// issue C0-03: the combat stage's transient readout must never stack on
// itself.
//
// Round-0 plates showed "+5 EMBERS — EXACT!" printed over the damage number
// and the live intent badge, a damage number sitting on a dead foe's badge,
// and "OVERKILL +3 → NEXT FOE" climbing out of the stage over the enemy HP
// caption. The old layout used fixed offsets (call-outs at bottom 150 + 24
// per index, numbers at bottom 120) that only suited one stage height; the
// stage is anywhere from ~86 px (320x568, rolled) to ~365 px (412x915) tall.
//
// This file is the ONE place that decides where stage text rests. It is pure
// geometry: from the stage box, the two bodies and the intent badge it plans
//   • an enemy damage-number ZONE (over the foe, low, under the badge — or
//     beside the foe toward the hero when the stage is too short),
//   • one or two call-out SLOTS stacked from the stage top, and
//   • the hero's damage-number zone,
// such that every piece's whole animated sweep (DamagePop.sweep /
// TextPop.sweep) stays inside the stage and clear of the badge (reserved even
// while it fades), of the number zones and of the other slot. Zones and slots
// are reserved whether or not something is showing, so nothing ever jumps
// mid-flight. Pinned by test/readout_lanes_test.dart (a sweep of stage
// geometries) and test/kill_readout_test.dart (real kills, every frame).
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'fx.dart';

/// One transient readout's resting box (stage coordinates, origin top-left)
/// and motion. [swept] bounds everything it paints over its visible life.
class ReadoutPlacement {
  final Rect box;
  final double rise;
  final double drift;
  final double overshoot;

  /// Fit scale for call-outs squeezed into a narrow band (1 = natural).
  final double scale;
  final Rect swept;
  const ReadoutPlacement({
    required this.box,
    required this.rise,
    required this.swept,
    this.drift = 0,
    this.overshoot = TextPop.defaultOvershoot,
    this.scale = 1,
  });
}

class StageGeometry {
  final Size stage;
  final Rect enemyBody;
  final Rect heroBody;

  /// The intent badge's box. Reserved whether or not it is showing.
  final Rect badge;
  const StageGeometry({
    required this.stage,
    required this.enemyBody,
    required this.heroBody,
    required this.badge,
  });

  @override
  bool operator ==(Object other) =>
      other is StageGeometry &&
      other.stage == stage &&
      other.enemyBody == enemyBody &&
      other.heroBody == heroBody &&
      other.badge == badge;

  @override
  int get hashCode => Object.hash(stage, enemyBody, heroBody, badge);
}

/// A call-out slot: a horizontal band at a fixed resting top with a fixed
/// motion. Any call-out scaled to fit the band stays inside [swept].
class NoteSlot {
  final double top;
  final double left;
  final double right;
  final double height;
  final double rise;
  final double overshoot;
  final Rect swept;
  const NoteSlot({
    required this.top,
    required this.left,
    required this.right,
    required this.height,
    required this.rise,
    required this.overshoot,
    required this.swept,
  });
  double get width => right - left;
}

class ReadoutPlan {
  final StageGeometry geometry;
  final ReadoutPlacement enemyPopZone;
  final ReadoutPlacement heroPopZone;

  /// Call-out slots, all above the actors' heads (C1-02). EMPTY when the
  /// stage has no room for a call-out at [minNoteScale] — a rolled 320x568
  /// stage is 86 px with both actors standing 72 px tall — and the screen
  /// then shows its call-outs in the tray lane instead.
  final List<NoteSlot> slots;

  /// C1-02: the smallest fit scale a call-out may be drawn at
  /// ([ReadoutLanes.minNoteSp] over the call-out's font size).
  final double minNoteScale;

  /// False only when the stage is too small for a clean plan; the pieces are
  /// then placed best-effort (tests pin which phone sizes must be clean).
  final bool clean;
  const ReadoutPlan({
    required this.geometry,
    required this.enemyPopZone,
    required this.heroPopZone,
    required this.slots,
    required this.clean,
    this.minNoteScale = 0,
  });

  /// A call-out of natural [size] in [slot]: scaled down to fit the band
  /// (overshoot included), centred, at the slot's resting top. Null when
  /// the slot does not exist or the call-out would have to shrink below
  /// [minNoteScale] to fit it (C1-02: no call-out under 12 sp) — the caller
  /// then gives it another lane.
  ReadoutPlacement? placeNote(int slot, Size size) {
    if (slot < 0 || slot >= slots.length) return null;
    final s = slots[slot];
    final scale = math.min(
      1.0,
      math.min(
        (s.width - 2) / (size.width * s.overshoot),
        s.height / math.max(1, size.height),
      ),
    );
    if (scale < minNoteScale - 1e-9) return null;
    final w = size.width * scale, h = size.height * scale;
    final box = Rect.fromLTWH(s.left + (s.width - w) / 2, s.top, w, h);
    return ReadoutPlacement(
      box: box,
      rise: s.rise,
      overshoot: s.overshoot,
      scale: scale,
      swept: ReadoutLanes.sweptNote(box, s.rise, s.overshoot),
    );
  }

  /// An enemy damage number of [size]; lane 0 is the planned zone, extra
  /// simultaneous numbers step toward the hero.
  ReadoutPlacement placeEnemyPop(Size size, {int lane = 0}) =>
      _placePop(enemyPopZone, size, lane, toward: -1, onPlayer: false);

  ReadoutPlacement placeHeroPop(Size size, {int lane = 0}) =>
      _placePop(heroPopZone, size, lane, toward: 1, onPlayer: true);

  ReadoutPlacement _placePop(
    ReadoutPlacement zone,
    Size size,
    int lane, {
    required int toward,
    required bool onPlayer,
  }) {
    // Same anchor (bottom-centre) as the planned zone, which was sized for
    // the widest likely number — a smaller number sweeps inside it.
    final cx = zone.box.center.dx + toward * lane * (size.width + 8);
    final box = Rect.fromLTWH(
      cx - size.width / 2,
      zone.box.bottom - size.height,
      size.width,
      size.height,
    );
    return ReadoutPlacement(
      box: box,
      rise: zone.rise,
      drift: zone.drift,
      swept: ReadoutLanes.sweptPop(box, zone.rise, zone.drift, onPlayer),
    );
  }
}

class ReadoutLanes {
  static const double gap = 4;
  static const int maxSlots = 2;

  /// C1-02: no call-out is ever drawn smaller than this (sp). Round-1 plates
  /// caught "+5 EMBERS — EXACT!" squeezed to ~5 dp on a 320x568 stage.
  static const double minNoteSp = 12;

  /// Far enough to stand for "the whole stage width" in avoid rects.
  static const double _far = 1e4;

  /// C1-02: the band the two actors stand in and sweep through (lunges,
  /// dashes, hit reactions) — from the taller head down past the floor,
  /// across the whole stage. Call-out slots are planned ABOVE it, so a
  /// call-out never prints over a sprite ([_clear] keeps [gap] of air).
  static Rect actorsBand(StageGeometry g) => Rect.fromLTRB(
    -_far,
    math.min(g.heroBody.top, g.enemyBody.top),
    _far,
    g.stage.height + _far,
  );

  static const _popRisesOver = [46.0, 36.0, 28.0, 20.0, 14.0];
  static const _popRisesBeside = [46.0, 32.0, 20.0, 12.0, 6.0, 0.0];
  static const _noteRises = [34.0, 22.0, 12.0, 6.0, 0.0];
  static const _overshoots = [1.2, 1.08];

  static final Map<String, EdgeInsets> _sweepCache = {};

  static EdgeInsets _cachedSweep(String key, EdgeInsets Function() compute) {
    if (_sweepCache.length > 512) _sweepCache.clear();
    return _sweepCache.putIfAbsent(key, compute);
  }

  static Rect sweptPop(Rect box, double rise, double drift, bool onPlayer) {
    final s = _cachedSweep(
      'p${box.width.toStringAsFixed(1)}x${box.height.toStringAsFixed(1)}'
      '/$rise/$drift/$onPlayer',
      () => DamagePop.sweep(
        box.size,
        rise: rise,
        drift: drift,
        onPlayer: onPlayer,
      ),
    );
    return Rect.fromLTRB(
      box.left - s.left,
      box.top - s.top,
      box.right + s.right,
      box.bottom + s.bottom,
    );
  }

  static Rect sweptNote(Rect box, double rise, double overshoot) {
    final s = _cachedSweep(
      'n${box.width.toStringAsFixed(1)}x${box.height.toStringAsFixed(1)}'
      '/$rise/$overshoot',
      () => TextPop.sweep(box.size, rise: rise, overshoot: overshoot),
    );
    return Rect.fromLTRB(
      box.left - s.left,
      box.top - s.top,
      box.right + s.right,
      box.bottom + s.bottom,
    );
  }

  static bool _inside(Rect r, Size stage) =>
      r.top >= -0.5 && r.bottom <= stage.height + 0.5;

  static bool _clear(Rect r, Iterable<Rect> others) =>
      others.every((o) => !r.inflate(gap / 2).overlaps(o.inflate(gap / 2)));

  static final Map<Object, ReadoutPlan> _planCache = {};

  /// The plan for [g]. [typicalPop] should be the widest likely number at the
  /// current text scale, [noteHeight] one call-out line's height and
  /// [typicalNoteWidth] a long call-out's natural width. Memoised: the
  /// search runs once per stage geometry.
  static ReadoutPlan plan(
    StageGeometry g, {
    required Size typicalPop,
    required double noteHeight,
    required double typicalNoteWidth,
    required double minNoteScale,
  }) {
    final key = (g, typicalPop, noteHeight, typicalNoteWidth, minNoteScale);
    final hit = _planCache[key];
    if (hit != null) return hit;
    if (_planCache.length > 64) _planCache.clear();
    return _planCache[key] = _search(
      g,
      typicalPop,
      noteHeight,
      typicalNoteWidth,
      minNoteScale,
    );
  }

  static Iterable<ReadoutPlacement> _enemyPopCandidates(
    StageGeometry g,
    Size pop,
  ) sync* {
    final body = g.enemyBody;
    // 1) Over the foe, low (30% up from the feet), under the badge.
    for (final rise in _popRisesOver) {
      final box = Rect.fromLTWH(
        body.center.dx - pop.width / 2,
        body.bottom - body.height * 0.30 - pop.height,
        pop.width,
        pop.height,
      );
      final swept = sweptPop(box, rise, DamagePop.defaultDrift, false);
      if (_inside(swept, g.stage) && _clear(swept, [g.badge])) {
        yield ReadoutPlacement(
          box: box,
          rise: rise,
          drift: DamagePop.defaultDrift,
          swept: swept,
        );
      }
    }
    // 2) Beside the foe on the side the blow came from, clear of the badge
    //    column, hugging the floor (call-out slots live at the top).
    const drift = 8.0;
    final edge = math.min(body.left, g.badge.left) - gap;
    for (final rise in _popRisesBeside) {
      final x = edge - pop.width - drift;
      final probe = Rect.fromLTWH(x, 0, pop.width, pop.height);
      final s = sweptPop(probe, rise, drift, false);
      if (s.height > g.stage.height) continue;
      final floorTop = g.stage.height - (s.bottom - probe.bottom) - pop.height;
      final box = Rect.fromLTWH(x, floorTop, pop.width, pop.height);
      final swept = sweptPop(box, rise, drift, false);
      if (_inside(swept, g.stage) && _clear(swept, [g.badge])) {
        yield ReadoutPlacement(
          box: box,
          rise: rise,
          drift: drift,
          swept: swept,
        );
      }
    }
  }

  static NoteSlot? _slot(
    StageGeometry g, {
    required double top,
    required double height,
    required double rise,
    required double overshoot,
    required double left,
    required double right,
    required List<Rect> avoid,
  }) {
    final box = Rect.fromLTRB(left, top, right, top + height);
    // The band is fully reserved; narrower call-outs are scaled to fit it,
    // so their sweep can only be smaller. Overshoot growth is inside the
    // band by construction (width * overshoot <= band), so reserve the
    // vertical growth plus the rise.
    final probe = sweptNote(
      Rect.fromLTWH(0, top, (right - left) / overshoot, height),
      rise,
      overshoot,
    );
    final swept = Rect.fromLTRB(left, probe.top, right, probe.bottom);
    if (!_inside(swept, g.stage) || !_clear(swept, avoid)) return null;
    return NoteSlot(
      top: box.top,
      left: left,
      right: right,
      height: height,
      rise: rise,
      overshoot: overshoot,
      swept: swept,
    );
  }

  /// The highest slot at or below [minTop] that fits: biggest rise first,
  /// then the widest band (the full stage, left of the badge, left of the
  /// badge and the number zone), scanning resting tops downward.
  static NoteSlot? _firstSlot(
    StageGeometry g, {
    required double height,
    required double typicalWidth,
    required double minScale,
    required List<Rect> avoid,
    required double minTop,
    required List<({double left, double right})> bands,
  }) {
    for (final rise in _noteRises) {
      for (final (i, b) in bands.indexed) {
        final width = b.right - b.left;
        // Only the full-width band can afford the big pop-in overshoot.
        for (final overshoot in i == 0 ? _overshoots : const [1.08]) {
          // C1-02: a long call-out must fit at the 12 sp floor (it used to
          // be allowed down to 72%, and the fallback had no floor at all).
          if ((width - 2) / (typicalWidth * overshoot) < minScale) continue;
          final head = sweptNote(
            Rect.fromLTWH(0, 0, width / overshoot, height),
            rise,
            overshoot,
          );
          for (
            var top = math.max(minTop, -head.top + gap / 2);
            top + height <= g.stage.height;
            top += 2
          ) {
            final s = _slot(
              g,
              top: top,
              height: height,
              rise: rise,
              overshoot: overshoot,
              left: b.left,
              right: b.right,
              avoid: avoid,
            );
            if (s != null) return s;
          }
        }
      }
    }
    return null;
  }

  static ReadoutPlan _search(
    StageGeometry g,
    Size pop,
    double noteH,
    double noteW,
    double minScale,
  ) {
    final w = g.stage.width;
    // Best plan first: clean WITH call-out slots; then clean with none (the
    // call-outs take the tray lane); then best effort.
    ReadoutPlan? cleanNoSlots, fallback;
    for (final zone in _enemyPopCandidates(g, pop)) {
      final avoid = [g.badge, zone.swept];
      // C1-02: call-outs live above the actors' heads, never on a sprite.
      final slotAvoid = [...avoid, actorsBand(g)];
      final bands = [
        (left: 0.0, right: w),
        (left: 0.0, right: g.badge.left - gap),
        (left: 0.0, right: math.min(g.badge.left, zone.swept.left) - gap),
      ];
      final first = _firstSlot(
        g,
        height: noteH,
        typicalWidth: noteW,
        minScale: minScale,
        avoid: slotAvoid,
        minTop: 0,
        bands: bands,
      );
      final slots = <NoteSlot>[?first];
      if (first != null) {
        final second = _firstSlot(
          g,
          height: noteH,
          typicalWidth: noteW,
          minScale: minScale,
          avoid: [...slotAvoid, first.swept],
          minTop: first.top + noteH + gap,
          bands: bands,
        );
        if (second != null) slots.add(second);
      }
      final hero = _heroZone(g, pop, [
        ...avoid,
        for (final s in slots) s.swept,
      ]);
      final plan = ReadoutPlan(
        geometry: g,
        enemyPopZone: zone,
        heroPopZone: hero.$1,
        slots: slots,
        clean: hero.$2,
        minNoteScale: minScale,
      );
      if (plan.clean && slots.isNotEmpty) return plan;
      if (plan.clean) {
        cleanNoSlots ??= plan;
      } else {
        fallback ??= plan;
      }
    }
    if (cleanNoSlots != null) return cleanNoSlots;
    if (fallback != null) return fallback;
    // Nothing fits cleanly (a tiny stage): best effort, no motion, and no
    // call-out slot at all — a squeezed slot is how "+5 EMBERS — EXACT!"
    // ended up ~5 dp tall on the hero's helmet (C1-02).
    final zone =
        _enemyPopCandidates(g, pop).firstOrNull ??
        ReadoutPlacement(
          box: Rect.fromLTWH(
            g.enemyBody.left - pop.width - gap,
            math.max(0, g.stage.height - pop.height) / 2,
            pop.width,
            pop.height,
          ),
          rise: 0,
          swept: Rect.fromLTWH(
            g.enemyBody.left - pop.width - gap,
            math.max(0, g.stage.height - pop.height) / 2,
            pop.width,
            pop.height,
          ),
        );
    return ReadoutPlan(
      geometry: g,
      enemyPopZone: zone,
      heroPopZone: _heroZone(g, pop, [g.badge, zone.swept]).$1,
      slots: const [],
      clean: false,
      minNoteScale: minScale,
    );
  }

  /// C1-06: the hero's hit number keeps this much air from the delver's box,
  /// so the number and the hit reaction never share pixels.
  static const double heroClearance = 6;

  /// Hero number. Returns (placement, clean).
  ///
  /// C1-06: the number must not sit ON the delver — the hit reaction (white
  /// beat, jolt, red tint) plays there. It goes ABOVE the head when the stage
  /// has room (the round-0 look), else BESIDE the delver on the fight side,
  /// each clear of the body by [heroClearance] and kept on the stage (the
  /// number drifts left, toward the delver at the stage's left edge). Only a
  /// stage with no room off the body falls back to the old over-the-chest
  /// zone, which is unchanged and still plans clean exactly as before.
  static (ReadoutPlacement, bool) _heroZone(
    StageGeometry g,
    Size pop,
    List<Rect> avoid,
  ) {
    final body = g.heroBody;
    final offBody = [...avoid, body.inflate(heroClearance)];
    // [_clear] pads both rects by gap/2, so a sweep must keep this far from
    // the body's edge to pass the [offBody] check.
    const apartBy = heroClearance + gap;
    // 1) Above the head, rising as far as the stage and the slots allow. The
    //    resting box is lifted until its WHOLE sweep (pop-in growth included)
    //    ends above the head.
    for (final rise in _popRisesBeside) {
      var p = _heroPlacement(
        g,
        Rect.fromLTWH(
          body.center.dx - pop.width / 2,
          body.top - pop.height,
          pop.width,
          pop.height,
        ),
        rise,
      );
      final up = p.swept.bottom - (body.top - apartBy);
      if (up > 0) p = _heroPlacement(g, p.box.shift(Offset(0, -up)), rise);
      if (_onStage(p.swept, g.stage) && _clear(p.swept, offBody)) {
        return (p, true);
      }
    }
    // 2) Beside the delver on the fight side: chest height, lower, then
    //    hugging the floor (short stages keep their top for call-outs).
    for (final rise in _popRisesBeside) {
      for (final lift in const [0.45, 0.30, 0.15, -1.0]) {
        var box = Rect.fromLTWH(
          body.right,
          body.bottom - body.height * lift - pop.height,
          pop.width,
          pop.height,
        );
        if (lift < 0) {
          final probe = sweptPop(box, rise, DamagePop.defaultDrift, true);
          box = box.shift(Offset(0, g.stage.height - probe.bottom));
        }
        // It drifts LEFT (toward the delver): push the resting box right
        // until the whole sweep clears the body.
        var p = _heroPlacement(g, box, rise);
        final push = body.right + apartBy - p.swept.left;
        if (push > 0) p = _heroPlacement(g, p.box.shift(Offset(push, 0)), rise);
        if (_onStage(p.swept, g.stage) && _clear(p.swept, offBody)) {
          return (p, true);
        }
      }
    }
    // 3) No room off the body: the old zone, unchanged — over the chest, then
    //    lower, then hugging the floor.
    ReadoutPlacement? first;
    for (final rise in _popRisesBeside) {
      // Over the chest, then lower, then hugging the floor (short stages
      // keep the top for call-outs).
      for (final lift in const [0.45, 0.30, 0.15, -1.0]) {
        var box = Rect.fromLTWH(
          body.center.dx - pop.width / 2,
          body.bottom - body.height * lift - pop.height,
          pop.width,
          pop.height,
        );
        if (lift < 0) {
          final probe = sweptPop(box, rise, DamagePop.defaultDrift, true);
          box = box.shift(Offset(0, g.stage.height - probe.bottom));
        }
        final swept = sweptPop(box, rise, DamagePop.defaultDrift, true);
        final p = ReadoutPlacement(
          box: box,
          rise: rise,
          drift: DamagePop.defaultDrift,
          swept: swept,
        );
        first ??= p;
        if (_inside(swept, g.stage) && _clear(swept, avoid)) return (p, true);
      }
    }
    return (first!, false);
  }

  /// A hero-number placement resting at [box], shifted right if its leftward
  /// drift would carry it past the stage's left edge (C1-06).
  static ReadoutPlacement _heroPlacement(
    StageGeometry g,
    Rect box,
    double rise,
  ) {
    var b = box;
    var swept = sweptPop(b, rise, DamagePop.defaultDrift, true);
    if (swept.left < 0) {
      b = b.shift(Offset(-swept.left, 0));
      swept = sweptPop(b, rise, DamagePop.defaultDrift, true);
    }
    return ReadoutPlacement(
      box: b,
      rise: rise,
      drift: DamagePop.defaultDrift,
      swept: swept,
    );
  }

  /// [_inside] plus the horizontal bounds, for zones that must not slide off
  /// either side of the stage.
  static bool _onStage(Rect r, Size stage) =>
      _inside(r, stage) && r.left >= -0.5 && r.right <= stage.width + 0.5;
}

/// C0-03 + C1-02: the tray lane — ONE call-out slot in the strip between the
/// player's HP bar and the dice, beside the HP caption ("YOUR HP"). Nothing
/// else ever paints there: it is clear of the HP numerals, the bar, the
/// caption, the dice and every sprite at every phone size (the round-1
/// plates caught "STRAIGHT!" on the HP bar next to "21 / 30" and FREE REROLL
/// across the hero's feet). Pure geometry in the tray's own coordinates
/// (origin: the tray's top-left; the strip sits above it, so its top is
/// negative). A call-out that cannot fit here at the 12 sp floor gets null.
class TrayLane {
  /// The strip a call-out's whole sweep (pop-in growth and rise) stays in.
  final Rect band;

  /// Where a call-out centres when it can: the tray's middle, over the dice.
  final double centreX;

  /// [ReadoutLanes.minNoteSp] over the tray call-outs' font size.
  final double minNoteScale;
  const TrayLane({
    required this.band,
    required this.centreX,
    required this.minNoteScale,
  });

  /// [trayWidth]: the tray's inner width. [gapAbove]: the spacer between the
  /// HP block and the tray. [caption]: the HP caption's laid-out size (it
  /// sits left-aligned at the bottom of the HP block). [barGap]: the spacer
  /// between the HP bar and the caption.
  factory TrayLane.measure({
    required double trayWidth,
    required double gapAbove,
    required Size caption,
    required double barGap,
    required double minNoteScale,
  }) => TrayLane(
    band: Rect.fromLTRB(
      caption.width + 2 * ReadoutLanes.gap,
      -(gapAbove + caption.height + barGap) + 1,
      trayWidth,
      -1,
    ),
    centreX: trayWidth / 2,
    minNoteScale: minNoteScale,
  );

  static const _rises = [12.0, 8.0, 5.0, 3.0, 0.0];
  static const _overshoots = [1.08, 1.0];

  @override
  bool operator ==(Object other) =>
      other is TrayLane &&
      other.band == band &&
      other.centreX == centreX &&
      other.minNoteScale == minNoteScale;

  @override
  int get hashCode => Object.hash(band, centreX, minNoteScale);

  /// A call-out of natural [size] in this lane: scaled down only as far as
  /// the strip needs (never below [minNoteScale] unless [squeeze] — the
  /// last resort for a call-out that fits no slot anywhere), centred over
  /// the dice when that clears the caption, resting low and rising as far
  /// as the strip allows.
  ReadoutPlacement? place(Size size, {bool squeeze = false}) {
    for (final overshoot in _overshoots) {
      var scale = math.min(
        1.0,
        math.min(
          (band.width - 2) / (size.width * overshoot),
          (band.height - 1) / (math.max(1, size.height) * overshoot),
        ),
      );
      if (scale < minNoteScale - 1e-9) {
        if (!squeeze || overshoot != _overshoots.last) continue;
        scale = math.max(scale, 0.05);
      }
      final w = size.width * scale, h = size.height * scale;
      final half = w * overshoot / 2;
      final lo = band.left + half + 1, hi = band.right - half - 1;
      final cx = lo > hi ? band.center.dx : centreX.clamp(lo, hi);
      for (final rise in _rises) {
        var box = Rect.fromLTWH(cx - w / 2, band.bottom - h, w, h);
        var swept = ReadoutLanes.sweptNote(box, rise, overshoot);
        box = box.shift(Offset(0, band.bottom - swept.bottom));
        swept = ReadoutLanes.sweptNote(box, rise, overshoot);
        if (swept.top >= band.top - 0.5 || (squeeze && rise == 0)) {
          return ReadoutPlacement(
            box: box,
            rise: rise,
            overshoot: overshoot,
            scale: scale,
            swept: swept,
          );
        }
      }
    }
    return null;
  }
}
