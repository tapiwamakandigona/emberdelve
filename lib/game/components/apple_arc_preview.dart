// AKP-4c: apple arc preview — subtle dotted trajectory shown only while the
// throw button is held (with apples in the pouch). AK has no aim assist; this
// is a deliberate fairness win for touch (feel-notes: the flat lob is harder
// to aim on a phone than with AK's mouse-adjacent thumbstick muscle memory),
// kept faint so it reads as UI, not as part of the world.
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../ember_game.dart';
import '../tuning.dart';

class AppleArcPreview extends PositionComponent
    with HasGameReference<EmberGame> {
  AppleArcPreview() : super(priority: 4);

  // Preallocated buffers + one reused paint: zero per-frame allocations.
  final List<double> _xs = List.filled(kApplePreviewDots, 0);
  final List<double> _ys = List.filled(kApplePreviewDots, 0);
  static final _paint = ui.Paint();
  static const _apple = ui.Color(0xFFB6D53C);
  int _dots = 0;

  @override
  void update(double dt) {
    _dots = game.throwPreviewActive ? game.session.appleArcPreview(_xs, _ys) : 0;
  }

  @override
  void render(ui.Canvas canvas) {
    for (var i = 0; i < _dots; i++) {
      // Fade out along the flight so the eye lands on the launch window.
      final a = 0.55 * (1 - i / (kApplePreviewDots * 1.4));
      _paint.color = _apple.withValues(alpha: a);
      canvas.drawCircle(ui.Offset(_xs[i], _ys[i]), 1.2, _paint);
    }
  }
}
