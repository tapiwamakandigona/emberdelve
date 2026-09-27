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
  final List<NoteSlot> slots;

  /// False only when the stage is too small for a clean plan; the pieces are
  /// then placed best-effort (tests pin which phone sizes must be clean).
  final bool clean;
  const ReadoutPlan({
    required this.geometry,
    required this.enemyPopZone,
    required this.heroPopZone,
    required this.slots,
    required this.clean,
  });

  /// A call-out of natural [size] in [slot]: scaled down to fit the band
  /// (overshoot included), centred, at the slot's resting top.
  ReadoutPlacement placeNote(int slot, Size size) {
    final s = slots[slot.clamp(0, slots.length - 1)];
    final scale = math.min(
      1.0,
      math.min(
        (s.width - 2) / (size.width * s.overshoot),
        s.height / math.max(1, size.height),
      ),
    );
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
  }) {
    final key = (g, typicalPop, noteHeight, typicalNoteWidth);
    final hit = _planCache[key];
    if (hit != null) return hit;
    if (_planCache.length > 64) _planCache.clear();
    return _planCache[key] = _search(
      g,
      typicalPop,
      noteHeight,
      typicalNoteWidth,
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
    required List<Rect> avoid,
    required double minTop,
    required List<({double left, double right})> bands,
  }) {
    for (final rise in _noteRises) {
      for (final (i, b) in bands.indexed) {
        final width = b.right - b.left;
        // Only the full-width band can afford the big pop-in overshoot.
        for (final overshoot in i == 0 ? _overshoots : const [1.08]) {
          // A long call-out must stay readable (>= 72% of its size).
          if (width / (typicalWidth * overshoot) < 0.72) continue;
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
  ) {
    final w = g.stage.width;
    ReadoutPlan? fallback;
    for (final zone in _enemyPopCandidates(g, pop)) {
      final avoid = [g.badge, zone.swept];
      final bands = [
        (left: 0.0, right: w),
        (left: 0.0, right: g.badge.left - gap),
        (left: 0.0, right: math.min(g.badge.left, zone.swept.left) - gap),
      ];
      final first = _firstSlot(
        g,
        height: noteH,
        typicalWidth: noteW,
        avoid: avoid,
        minTop: 0,
        bands: bands,
      );
      if (first == null) continue;
      final slots = [first];
      final second = _firstSlot(
        g,
        height: noteH,
        typicalWidth: noteW,
        avoid: [...avoid, first.swept],
        minTop: first.top + noteH + gap,
        bands: bands,
      );
      if (second != null) slots.add(second);
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
      );
      if (plan.clean) return plan;
      fallback ??= plan;
    }
    if (fallback != null) return fallback;
    // Nothing fits cleanly (a tiny stage): best effort, no motion.
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
    final slot = NoteSlot(
      top: 0,
      left: 0,
      right: math.max(1, math.min(g.badge.left, zone.swept.left) - gap),
      height: noteH,
      rise: 0,
      overshoot: 1.0,
      swept: Rect.fromLTWH(0, 0, math.max(1, g.badge.left - gap), noteH),
    );
    return ReadoutPlan(
      geometry: g,
      enemyPopZone: zone,
      heroPopZone: _heroZone(g, pop, [g.badge, zone.swept, slot.swept]).$1,
      slots: [slot],
      clean: false,
    );
  }

  /// Hero number: over the hero, rising as far as the stage and the other
  /// reservations allow. Returns (placement, clean).
  static (ReadoutPlacement, bool) _heroZone(
    StageGeometry g,
    Size pop,
    List<Rect> avoid,
  ) {
    final body = g.heroBody;
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
}
