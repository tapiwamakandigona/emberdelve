// Static tile rendering: ONE component, one SpriteBatch canvas pass for the
// tileset (grass-top/dirt variants), plus tiny batches for platform + spike
// props and a shared animated flame for fire tiles. No per-tile components.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../ember_game.dart';
import '../level/level_data.dart';
import '../tuning.dart';

class TileLayerComponent extends PositionComponent
    with HasGameReference<EmberGame> {
  TileLayerComponent() : super(priority: 0);

  late SpriteBatch _tiles;
  late SpriteBatch _platforms;
  late SpriteBatch _spikes;
  late ui.Image _blockBig;
  late SpriteAnimationTicker _fireTicker;
  late SpriteAnimation _fireAnim;
  // Draw positions (already offset a tile up: the 16x32 flame rises above
  // the fire tile), precomputed in [rebuild] so render never allocates.
  final List<Vector2> _firePositions = [];
  static final _fireSize = Vector2(16, 32);

  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final _wallPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..colorFilter = const ui.ColorFilter.mode(
        ui.Color(0xFF9A9AB0), ui.BlendMode.modulate); // darker tint

  // Atlas coords in 16px tile units (grass-top / dirt-fill variants).
  static const _grass = [(1, 1), (3, 1), (5, 1)];
  static const _dirt = [(1, 3), (3, 3), (5, 3)];

  @override
  Future<void> onLoad() async {
    final atlas = game.session.level.environment == 'cave'
        ? 'tiles/tileset_cave.png'
        : 'tiles/tileset.png';
    _tiles = await SpriteBatch.load(atlas, images: game.images);
    _platforms =
        await SpriteBatch.load('props/platform.png', images: game.images);
    _spikes = await SpriteBatch.load('props/spikes.png', images: game.images);
    _blockBig = await game.images.load('props/block_big.png');
    final fireImage = await game.images.load('fx/fire.png');
    _fireAnim = SpriteAnimation.fromFrameData(
      fireImage,
      SpriteAnimationData.sequenced(
          amount: 3, stepTime: 0.12, textureSize: Vector2(16, 32)),
    );
    _fireTicker = _fireAnim.createTicker();
    rebuild();
  }

  /// (Re)build all static batches from the session grid. Called on load and
  /// whenever a cracked wall breaks (session.wallsDirty).
  void rebuild() {
    final session = game.session;
    _tiles.clear();
    _platforms.clear();
    _spikes.clear();
    _firePositions.clear();

    for (var y = 0; y < session.level.height; y++) {
      for (var x = 0; x < session.level.width; x++) {
        final t = session.tileAt(x, y);
        final px = x * kTileSize, py = y * kTileSize;
        switch (t) {
          case TileKind.solid:
            final grassTop = session.tileAt(x, y - 1) == TileKind.empty ||
                session.tileAt(x, y - 1) == TileKind.platform ||
                session.tileAt(x, y - 1) == TileKind.spikes ||
                session.tileAt(x, y - 1) == TileKind.fire;
            // Only truly-empty above counts as exposed grass; hazards sit ON
            // the tile, so keep grass under them too (reads better).
            final variant = (x * 7 + y * 13) % 3;
            final (ax, ay) = grassTop ? _grass[variant] : _dirt[variant];
            _tiles.add(
              source: ui.Rect.fromLTWH(ax * 16.0, ay * 16.0, 16, 16),
              offset: Vector2(px, py),
            );
          case TileKind.platform:
            _platforms.add(
              source: const ui.Rect.fromLTWH(0, 0, 16, 16),
              offset: Vector2(px, py),
            );
          case TileKind.spikes:
            // Spikes sprite is 15x10: draw at the tile bottom.
            _spikes.add(
              source: const ui.Rect.fromLTWH(0, 0, 15, 10),
              offset: Vector2(px, py + kTileSize - 10),
            );
          case TileKind.fire:
            _firePositions.add(Vector2(px, py - kTileSize));
          case TileKind.crackedWall:
          case TileKind.empty:
            break;
        }
      }
    }
  }

  @override
  void update(double dt) {
    _fireTicker.update(dt);
    if (game.session.wallsDirty) {
      game.session.wallsDirty = false;
      rebuild();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    _tiles.render(canvas, paint: _paint);
    _platforms.render(canvas, paint: _paint);
    _spikes.render(canvas, paint: _paint);

    // Cracked walls: block_big (32x32) scaled onto the tile, tinted darker.
    for (final w in game.session.walls) {
      if (w.hp <= 0) continue;
      canvas.drawImageRect(
        _blockBig,
        const ui.Rect.fromLTWH(0, 0, 32, 32),
        ui.Rect.fromLTWH(
            w.tx * kTileSize, w.ty * kTileSize, kTileSize, kTileSize),
        _wallPaint,
      );
    }

    // Fire: 16x32 frames drawn with a 16px base on the tile, flame rising
    // above it (positions pre-offset in rebuild; zero per-frame allocations).
    final fireSprite = _fireTicker.getSprite();
    for (final p in _firePositions) {
      fireSprite.render(canvas, position: p, size: _fireSize);
    }
  }
}
