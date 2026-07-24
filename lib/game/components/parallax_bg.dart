// Forest parallax backdrop: hand-rolled (full control over factors, no
// Parallax API surprises). Lives in camera.backdrop, so it draws in viewport
// space; layer offsets derive from the camera position each frame.
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../ember_game.dart';

class ParallaxBackground extends Component with HasGameReference<EmberGame> {
  static const _layers = [
    ('bg/forest_back.png', 0.15),
    ('bg/forest_middle.png', 0.35),
    ('bg/forest_lights.png', 0.5),
    ('bg/forest_front.png', 0.7),
  ];

  final List<(ui.Image, double)> _images = [];
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    for (final (path, factor) in _layers) {
      _images.add((await game.images.load(path), factor));
    }
  }

  @override
  void render(ui.Canvas canvas) {
    const viewW = EmberGame.viewWidth, viewH = EmberGame.viewHeight;
    final camX = game.cameraPos.x;
    for (final (img, factor) in _images) {
      final scale = viewH / img.height;
      final w = img.width * scale;
      // Scroll opposite to camera, wrapped for infinite tiling.
      var offset = (-camX * factor) % w;
      if (offset > 0) offset -= w;
      final src = ui.Rect.fromLTWH(
          0, 0, img.width.toDouble(), img.height.toDouble());
      for (var x = offset; x < viewW; x += w) {
        canvas.drawImageRect(
            img, src, ui.Rect.fromLTWH(x, 0, w + 0.5, viewH), _paint);
      }
    }
  }
}
