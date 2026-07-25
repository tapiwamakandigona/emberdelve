// Forest parallax backdrop: hand-rolled (full control over factors, no
// Parallax API surprises). Lives in camera.backdrop, so it draws in viewport
// space; layer offsets derive from the camera position each frame.
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../ember_game.dart';

class ParallaxBackground extends Component with HasGameReference<EmberGame> {
  static const _factors = [
    ('back', 0.15),
    ('middle', 0.35),
    ('lights', 0.5),
    ('front', 0.7),
  ];

  // Per-layer draw state, precomputed at load: image, parallax factor,
  // full-image src rect, and view-scaled width (render stays allocation-lean:
  // only the moving dst Rect is built per draw call, as the canvas API needs).
  final List<(ui.Image, double, ui.Rect, double)> _images = [];
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    const viewH = EmberGame.viewHeight;
    final family =
        game.session.level.environment == 'cave' ? 'cave' : 'forest';
    for (final (layer, factor) in _factors) {
      final path = 'bg/${family}_$layer.png';
      final img = await game.images.load(path);
      final src = ui.Rect.fromLTWH(
          0, 0, img.width.toDouble(), img.height.toDouble());
      final w = img.width * (viewH / img.height);
      _images.add((img, factor, src, w));
    }
  }

  @override
  void render(ui.Canvas canvas) {
    const viewW = EmberGame.viewWidth, viewH = EmberGame.viewHeight;
    final camX = game.cameraPos.x;
    for (final (img, factor, src, w) in _images) {
      // Scroll opposite to camera, wrapped for infinite tiling.
      var offset = (-camX * factor) % w;
      if (offset > 0) offset -= w;
      for (var x = offset; x < viewW; x += w) {
        canvas.drawImageRect(
            img, src, ui.Rect.fromLTWH(x, 0, w + 0.5, viewH), _paint);
      }
    }
  }
}
