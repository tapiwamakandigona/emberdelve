// PerfOverlay: opt-in frame-time readout for device profiling (P-M7).
// Enabled only when built with --dart-define=PERF_OVERLAY=true — testers can
// then report honest fps/frame-time numbers from real hardware without
// DevTools. Shows fps (1s window), avg ms and worst ms per window; goes
// amber when the worst frame in the window blew the 16.7ms budget.
//
// Stats logic lives in [FrameStats] (pure Dart, unit-tested); the component
// only draws. Text re-layouts once per window, not per frame (see hud.dart).
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextPainter;

/// Aggregates frame times over fixed windows (default 1s).
class FrameStats {
  FrameStats({this.window = 1.0});

  final double window;
  double _acc = 0;
  int _frames = 0;
  double _worst = 0;

  // Published once per window.
  double fps = 0;
  double avgMs = 0;
  double worstMs = 0;
  int generation = 0; // bumps when a window closes (render cache key)

  /// Feed one frame's dt (seconds). Returns true when a window just closed.
  bool add(double dt) {
    if (dt <= 0) return false;
    _acc += dt;
    _frames++;
    if (dt > _worst) _worst = dt;
    if (_acc < window) return false;
    fps = _frames / _acc;
    avgMs = _acc / _frames * 1000;
    worstMs = _worst * 1000;
    generation++;
    _acc = 0;
    _frames = 0;
    _worst = 0;
    return true;
  }

  bool get overBudget => worstMs > 16.7;
}

class PerfOverlay extends PositionComponent {
  PerfOverlay() : super(priority: 100);

  final stats = FrameStats();

  static final _ok = TextPaint(
    style: const TextStyle(
        fontSize: 8, color: ui.Color(0xFF8FBF3F), fontFamily: 'Inter'),
  );
  static final _warn = TextPaint(
    style: const TextStyle(
        fontSize: 8, color: ui.Color(0xFFE8A33D), fontFamily: 'Inter'),
  );
  static final _back = ui.Paint()..color = const ui.Color(0x88141420);

  int _shownGeneration = -1;
  TextPainter? _tp;
  ui.Rect _bg = ui.Rect.zero;

  @override
  void update(double dt) => stats.add(dt);

  @override
  void render(ui.Canvas canvas) {
    if (stats.generation == 0) return; // first window still filling
    if (stats.generation != _shownGeneration) {
      _shownGeneration = stats.generation;
      final style = stats.overBudget ? _warn : _ok;
      _tp = style.toTextPainter(
          '${stats.fps.toStringAsFixed(0)} fps  '
          'avg ${stats.avgMs.toStringAsFixed(1)}ms  '
          'worst ${stats.worstMs.toStringAsFixed(1)}ms');
      _bg = ui.Rect.fromLTWH(0, 0, _tp!.width + 6, _tp!.height + 4);
    }
    final tp = _tp;
    if (tp == null) return;
    canvas.drawRect(_bg, _back);
    tp.paint(canvas, const ui.Offset(3, 2));
  }
}
