// lib/ui/ashfall.dart — "Ashfall": a slain foe crumbles into its own art
// pixels. Presentation only: it plays inside the death beat the choreography
// already waits out (`_deathTime`), reads nothing from the simulation and
// changes no timing.
//
// Why pixels rather than more particles: the Sept-13 critique asked for body
// acting over distant effects. Every enemy sheet is authored art upscaled by
// an integer factor (sprite_meta.json `scale`, uniform blocks — verified for
// all 42 sheets), so each block IS one art pixel. The body itself breaks up:
// heat runs across it from the side the blow came from, each pixel flares
// ember -> gold, tears loose and drifts away as cooling ash. Every foe gets
// it with zero new assets and one draw call per pass.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sprites.dart';
import 'theme.dart';

/// One art pixel's state at a moment of the crumble. [dx]/[dy] are screen
/// pixels from the pixel's home cell. See [AshfallModel.sample].
@immutable
class AshMote {
  final double dx;
  final double dy;

  /// Radians; loose motes tumble.
  final double rotation;

  /// 1.0 = a full art pixel; loose motes burn down as they fly.
  final double scale;

  /// 0 = cold, 1 = white-hot (the glow painted over the pixel).
  final double heat;

  /// 0 = the pixel's own colour, 1 = fully cooled to ash.
  final double cool;

  /// 0..1 overall opacity.
  final double alpha;

  /// Torn free of the body.
  final bool loose;

  const AshMote({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.scale,
    required this.heat,
    required this.cool,
    required this.alpha,
    required this.loose,
  });

  static const home = AshMote(
    dx: 0,
    dy: 0,
    rotation: 0,
    scale: 1,
    heat: 0,
    cool: 0,
    alpha: 1,
    loose: false,
  );
}

/// Deterministic crumble choreography for a [cols] x [rows] grid of art
/// pixels drawn [cell] screen pixels wide. Pure — no clock, no canvas — so
/// the timing contract is unit-testable: [sample] maps a SCREEN column
/// (0 = leftmost on screen), a row and normalised time 0..1 to a mote.
class AshfallModel {
  final int cols;
  final int rows;
  final double cell;

  /// +1: the blow came from screen-left, so the heat starts on the left edge
  /// and the ash drifts to screen-right. -1 mirrors both.
  final int away;

  /// Displacement off: the body still burns through in the same order, but
  /// no mote moves (reduce-motion friendly). Heat and fade are unchanged.
  final bool still;

  /// A pixel glows for this long (normalised) before it tears loose.
  static const double heatLead = 0.14;

  /// Life of a loose mote (normalised).
  static const double flight = 0.40;

  /// Every pixel is loose by here, so `lastBreak + flight < 1`: the body is
  /// completely gone before the death beat ends.
  static const double lastBreak = 0.58;
  static const double _firstBreak = 0.02;

  final Float32List _breakAt;
  final Float32List _vx;
  final Float32List _vy;
  final Float32List _buoy;
  final Float32List _spin;
  final Float32List _phase;

  AshfallModel({
    required this.cols,
    required this.rows,
    required this.cell,
    this.away = 1,
    this.still = false,
    int seed = 0,
  }) : assert(cols > 0 && rows > 0 && cell > 0),
       _breakAt = Float32List(cols * rows),
       _vx = Float32List(cols * rows),
       _vy = Float32List(cols * rows),
       _buoy = Float32List(cols * rows),
       _spin = Float32List(cols * rows),
       _phase = Float32List(cols * rows) {
    for (var gy = 0; gy < rows; gy++) {
      for (var sx = 0; sx < cols; sx++) {
        final i = gy * cols + sx;
        // 0 on the side facing the attacker, 1 on the far side.
        final across = (sx + 0.5) / cols;
        final u = away >= 0 ? across : 1.0 - across;
        final v = (gy + 0.5) / rows; // 0 = top
        // Mostly a sweep away from the blow, a little top-first (heat
        // rises), broken up by per-pixel noise so the front reads as
        // burning, not as a wipe.
        final raw = (0.55 * u + 0.20 * (1.0 - v) + 0.25 * _h(i, 1, seed)).clamp(
          0.0,
          1.0,
        );
        _breakAt[i] = _firstBreak + (lastBreak - _firstBreak) * raw;
        _vx[i] = 0.10 + 0.35 * _h(i, 2, seed);
        _vy[i] = 0.04 + 0.20 * _h(i, 3, seed);
        _buoy[i] = 0.20 + 0.30 * _h(i, 4, seed);
        _spin[i] = (_h(i, 5, seed) - 0.5) * 7.0;
        _phase[i] = _h(i, 6, seed) * 2 * math.pi;
      }
    }
  }

  /// Screen height of the whole body.
  double get height => rows * cell;

  /// When (normalised) the pixel at screen column [sx], row [gy] tears loose.
  double breakAt(int sx, int gy) => _breakAt[gy * cols + sx];

  /// Deterministic per-pixel hash in 0..1 (no Random allocations).
  static double _h(int i, int salt, int seed) {
    final v = math.sin(i * 127.1 + salt * 311.7 + seed * 74.7) * 43758.5453123;
    return v - v.floorToDouble();
  }

  AshMote sample(int sx, int gy, double t) {
    final i = gy * cols + sx;
    final b = _breakAt[i];
    final heatStart = math.max(0.0, b - heatLead);
    if (t <= heatStart) return AshMote.home;
    if (t < b) {
      // Glowing in place; a fine sizzle just before it goes.
      final heat = math.pow((t - heatStart) / (b - heatStart), 1.6).toDouble();
      final sizzle = still
          ? 0.0
          : math.sin(t * 90.0 + _phase[i]) * 0.22 * cell * heat;
      return AshMote(
        dx: sizzle,
        dy: 0,
        rotation: 0,
        scale: 1,
        heat: heat,
        cool: 0,
        alpha: 1,
        loose: false,
      );
    }
    final p = ((t - b) / flight).clamp(0.0, 1.0);
    final alpha = p >= 1.0
        ? 0.0
        : (p <= 0.4 ? 1.0 : (1.0 - (p - 0.4) / 0.6).clamp(0.0, 1.0));
    final h = height;
    return AshMote(
      dx: still
          ? 0
          : away * (_vx[i] * p + 0.15 * p * p) * h +
                math.sin(p * 6.5 + _phase[i]) * 0.6 * cell * p,
      dy: still ? 0 : -(_vy[i] * p + 0.5 * _buoy[i] * p * p) * h,
      rotation: still ? 0 : _spin[i] * p,
      scale: 1.0 - 0.55 * p,
      heat: (1.0 - p / 0.45).clamp(0.0, 1.0),
      cool: (p / 0.6).clamp(0.0, 1.0),
      alpha: alpha,
      loose: true,
    );
  }
}

/// The glow ramp: deep ember -> ember -> gold -> white-hot.
Color ashHeatColor(double heat) {
  final h = heat.clamp(0.0, 1.0);
  const deep = Color(0xFFD4541C);
  const whiteHot = Color(0xFFFFF3D6);
  if (h < 0.55) return Color.lerp(deep, EmberColors.ember, h / 0.55)!;
  if (h < 0.85) {
    return Color.lerp(EmberColors.ember, EmberColors.gold, (h - 0.55) / 0.3)!;
  }
  return Color.lerp(EmberColors.gold, whiteHot, (h - 0.85) / 0.15)!;
}

/// Cooled ash: the pixel's own colour is multiplied toward this.
const Color ashColor = EmberColors.textDisabled;

/// A sprite that crumbles into its own art pixels over [duration], then
/// holds empty. Same box as the [SpriteView] it replaces (height x frame
/// aspect), so swapping it in never moves the layout. Draws the idle row's
/// first frame of [spriteId] straight from the warm sheet cache; check
/// [SpriteAshfall.ready] first — an undecoded sheet renders an empty box.
class SpriteAshfall extends StatefulWidget {
  final String spriteId;
  final double height;
  final bool flipX;

  /// +1 = the killing blow came from screen-left (the delver's side).
  final int away;
  final Duration duration;

  /// See [AshfallModel.still].
  final bool still;
  final VoidCallback? onDone;

  const SpriteAshfall(
    this.spriteId, {
    super.key,
    required this.height,
    this.flipX = false,
    this.away = 1,
    this.duration = const Duration(milliseconds: 700),
    this.still = false,
    this.onDone,
  });

  /// True once [spriteId]'s sheet is decoded, i.e. the crumble can draw on
  /// its very first frame (combat falls back to the legacy fade otherwise).
  static bool ready(String spriteId) => cachedSheet(spriteId) != null;

  @override
  State<SpriteAshfall> createState() => _SpriteAshfallState();
}

class _SpriteAshfallState extends State<SpriteAshfall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  AshfallModel? _model;
  (int, int, double, int, bool)? _modelKey;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  AshfallModel _modelFor(int cols, int rows, double cell) {
    final key = (cols, rows, cell, widget.away, widget.still);
    if (_model == null || _modelKey != key) {
      _modelKey = key;
      _model = AshfallModel(
        cols: cols,
        rows: rows,
        cell: cell,
        away: widget.away,
        still: widget.still,
        seed: _stableSeed(widget.spriteId),
      );
    }
    return _model!;
  }

  static int _stableSeed(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % 1000;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = cachedSheet(widget.spriteId);
    final def = sheet?.def;
    final aspect = def == null ? 1.0 : def.frameW / def.frameH;
    final size = Size(widget.height * aspect, widget.height);
    if (sheet == null || def == null) return SizedBox.fromSize(size: size);
    final s = def.pixelScale;
    final cols = def.frameW ~/ s;
    final rows = def.frameH ~/ s;
    final row = def.row('idle') ?? def.rows.values.first;
    final model = _modelFor(cols, rows, widget.height / rows);
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _AshfallPainter(
          t: _t,
          image: sheet.image,
          model: model,
          pixelScale: s,
          frameTop: row.row * def.frameH,
          flipX: widget.flipX,
        ),
      ),
    );
  }
}

class _AshfallPainter extends CustomPainter {
  final Animation<double> t;
  final ui.Image image;
  final AshfallModel model;
  final int pixelScale;
  final int frameTop;
  final bool flipX;

  // Buffers are built once per painter (the instance survives across frames:
  // repaint rides the controller), so the hot path allocates nothing.
  late final int _n = model.cols * model.rows;
  late final Float32List _cellRects = _buildRects();
  late final Float32List _xf = Float32List(_n * 4);
  late final Float32List _rects = Float32List(_n * 4);
  late final Int32List _body = Int32List(_n);
  late final Float32List _gxf = Float32List(_n * 4);
  late final Float32List _grects = Float32List(_n * 4);
  late final Int32List _glow = Int32List(_n);
  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  _AshfallPainter({
    required this.t,
    required this.image,
    required this.model,
    required this.pixelScale,
    required this.frameTop,
    required this.flipX,
  }) : super(repaint: t);

  /// Source rect of every art pixel on the idle row's first frame, inset
  /// half a texel so nearest sampling never bleeds a neighbouring block.
  Float32List _buildRects() {
    final out = Float32List(_n * 4);
    final s = pixelScale.toDouble();
    final inset = pixelScale >= 2 ? 0.5 : 0.0;
    final side = pixelScale >= 2 ? s - 1.0 : 1.0;
    for (var gy = 0; gy < model.rows; gy++) {
      for (var gx = 0; gx < model.cols; gx++) {
        final o = (gy * model.cols + gx) * 4;
        final l = gx * s + inset;
        final tp = frameTop + gy * s + inset;
        out[o] = l;
        out[o + 1] = tp;
        out[o + 2] = l + side;
        out[o + 3] = tp + side;
      }
    }
    return out;
  }

  // 65-step colour ramps as packed RGB, so a frame builds ~1k colours with
  // integer math only (no Color objects in the hot path).
  static final Int32List _heatLut = _ramp(ashHeatColor);
  static final Int32List _coolLut = _ramp(
    (x) => Color.lerp(Colors.white, ashColor, x)!,
  );
  static Int32List _ramp(Color Function(double) f) => Int32List.fromList([
    for (var i = 0; i <= 64; i++) f(i / 64).toARGB32() & 0x00FFFFFF,
  ]);

  static int _argb(Int32List lut, double x, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    return (a << 24) | lut[(x.clamp(0.0, 1.0) * 64).round()];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    if (time >= 1.0) return;
    final cell = model.cell;
    final side = pixelScale >= 2 ? pixelScale - 1.0 : 1.0;
    final anchor = side / 2;
    var k = 0; // body quads
    var g = 0; // glow quads
    for (var gy = 0; gy < model.rows; gy++) {
      for (var gx = 0; gx < model.cols; gx++) {
        final sx = flipX ? model.cols - 1 - gx : gx;
        final m = model.sample(sx, gy, time);
        if (m.alpha <= 0.004 || m.scale <= 0.0) continue;
        final cx = (sx + 0.5) * cell + m.dx;
        final cy = (gy + 0.5) * cell + m.dy;
        final sc = cell * m.scale / side;
        final scos = sc * math.cos(m.rotation);
        final ssin = sc * math.sin(m.rotation);
        final tx = cx - scos * anchor + ssin * anchor;
        final ty = cy - ssin * anchor - scos * anchor;
        final src = (gy * model.cols + gx) * 4;
        final o = k * 4;
        _xf[o] = scos;
        _xf[o + 1] = ssin;
        _xf[o + 2] = tx;
        _xf[o + 3] = ty;
        _rects[o] = _cellRects[src];
        _rects[o + 1] = _cellRects[src + 1];
        _rects[o + 2] = _cellRects[src + 2];
        _rects[o + 3] = _cellRects[src + 3];
        _body[k] = _argb(_coolLut, m.cool, m.alpha);
        k++;
        final glowA = m.heat * m.alpha;
        if (glowA > 0.02) {
          final q = g * 4;
          _gxf[q] = scos;
          _gxf[q + 1] = ssin;
          _gxf[q + 2] = tx;
          _gxf[q + 3] = ty;
          _grects[q] = _cellRects[src];
          _grects[q + 1] = _cellRects[src + 1];
          _grects[q + 2] = _cellRects[src + 2];
          _grects[q + 3] = _cellRects[src + 3];
          _glow[g] = _argb(_heatLut, m.heat, glowA * 0.92);
          g++;
        }
      }
    }
    if (k == 0) return;
    // Pass 1 — the body: each pixel keeps its own colour, multiplied toward
    // ash as it cools; colour alpha fades it (atlas image = src, colour =
    // dst, so modulate is image x colour).
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_xf, 0, k * 4),
      Float32List.sublistView(_rects, 0, k * 4),
      Int32List.sublistView(_body, 0, k),
      BlendMode.modulate,
      null,
      _paint,
    );
    if (g == 0) return;
    // Pass 2 — the heat: a solid glow silhouette of each hot pixel (dstIn
    // keeps the colour where the image is opaque), laid over pass 1.
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_gxf, 0, g * 4),
      Float32List.sublistView(_grects, 0, g * 4),
      Int32List.sublistView(_glow, 0, g),
      BlendMode.dstIn,
      null,
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AshfallPainter old) =>
      old.t != t ||
      old.image != image ||
      old.model != model ||
      old.pixelScale != pixelScale ||
      old.frameTop != frameTop ||
      old.flipX != flipX;
}
