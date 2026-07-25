// DecorLayerComponent: purely visual set dressing (bush/rock/shrooms/tree)
// parsed from the level's decor legend. Static — positions are computed once
// at load into pre-baked draw rects, so render() is a straight loop of
// drawImageRect calls with zero per-frame allocation. Draws at priority -1:
// behind tiles, items, enemies and the player, in front of the parallax
// backdrop (which lives on the camera, not in the world).
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../ember_game.dart';
import '../level/level_data.dart';
import '../tuning.dart';

class DecorLayerComponent extends PositionComponent
    with HasGameReference<EmberGame> {
  DecorLayerComponent() : super(priority: -1);

  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final List<(ui.Image, ui.Rect, ui.Rect)> _draws = []; // (image, src, dst)

  static const _sprites = {
    DecorKind.bush: 'props/bush.png',
    DecorKind.rock: 'props/rock.png',
    DecorKind.shrooms: 'props/shrooms.png',
    DecorKind.tree: 'props/tree.png',
  };

  @override
  Future<void> onLoad() async {
    final images = <DecorKind, ui.Image>{};
    for (final e in _sprites.entries) {
      images[e.key] = await game.images.load(e.value);
    }
    for (final d in game.session.level.decor) {
      final img = images[d.kind]!;
      final w = img.width.toDouble(), h = img.height.toDouble();
      // Bottom-center anchored on the decor tile's bottom edge.
      final cx = (d.x + 0.5) * kTileSize;
      final bottom = (d.y + 1) * kTileSize;
      _draws.add((
        img,
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Rect.fromLTWH(cx - w / 2, bottom - h, w, h),
      ));
    }
  }

  @override
  void render(ui.Canvas canvas) {
    for (final (img, src, dst) in _draws) {
      canvas.drawImageRect(img, src, dst, _paint);
    }
  }
}
