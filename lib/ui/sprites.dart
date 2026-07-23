// lib/ui/sprites.dart — pixel-art sprite sheets, driven by the bundled
// assets/images/sprite_meta.json (frame size, rows = animation states, fps).
// Rendering is nearest-neighbour (FilterQuality.none) so pixels stay crisp.
//
// KNOWN ART GAP (see staging PROVENANCE): sheets carry idle/run rows only
// (heroes add a 1-frame hit row). Attack/death are choreographed in the UI
// layer with tweens + flashes, not sprite frames.
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One animation row on a sheet.
class SpriteRowDef {
  final String state;
  final int frames;
  final int row;
  const SpriteRowDef(this.state, this.frames, this.row);
}

/// One sprite sheet (an enemy or a playable character).
class SpriteSheetDef {
  final String id;
  final String assetPath;
  final int frameW;
  final int frameH;
  final Map<String, SpriteRowDef> rows; // state -> row
  final int fps;
  const SpriteSheetDef({
    required this.id,
    required this.assetPath,
    required this.frameW,
    required this.frameH,
    required this.rows,
    required this.fps,
  });

  SpriteRowDef? row(String state) => rows[state];
}

/// Parsed sprite_meta.json. Load once via [SpriteMeta.load]; cached.
class SpriteMeta {
  final Map<String, SpriteSheetDef> enemies;
  final Map<String, SpriteSheetDef> characters;
  const SpriteMeta({required this.enemies, required this.characters});

  SpriteSheetDef? sheet(String id) => enemies[id] ?? characters[id];

  static SpriteMeta? _cached;
  static Future<SpriteMeta>? _loading;

  static Future<SpriteMeta> load() {
    if (_cached != null) return Future.value(_cached);
    return _loading ??= rootBundle
        .loadString('assets/images/sprite_meta.json')
        .then((s) => _cached = parse(s));
  }

  /// Pure parser (also used by tests on the raw file).
  static SpriteMeta parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    Map<String, SpriteSheetDef> section(String key, String dir) {
      final out = <String, SpriteSheetDef>{};
      for (final e in (root[key] as List).cast<Map<String, dynamic>>()) {
        final id = e['id'] as String;
        final rows = <String, SpriteRowDef>{};
        for (final r in (e['rows'] as List).cast<Map<String, dynamic>>()) {
          rows[r['state'] as String] = SpriteRowDef(
              r['state'] as String, r['frames'] as int, r['row'] as int);
        }
        out[id] = SpriteSheetDef(
          id: id,
          assetPath: 'assets/images/$dir/$id.png',
          frameW: e['frame_w'] as int,
          frameH: e['frame_h'] as int,
          rows: rows,
          fps: e['fps'] as int? ?? 8,
        );
      }
      return out;
    }

    return SpriteMeta(
      enemies: section('enemies', 'enemies'),
      characters: section('characters', 'characters'),
    );
  }
}

// Decoded sheet images, cached per asset path.
final Map<String, ui.Image> _imageCache = {};
final Map<String, Future<ui.Image>> _imageLoading = {};

Future<ui.Image> _loadSheetImage(String assetPath) {
  final hit = _imageCache[assetPath];
  if (hit != null) return Future.value(hit);
  return _imageLoading[assetPath] ??= () async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return _imageCache[assetPath] = frame.image;
  }();
}

/// A sprite from a sheet. `animate: true` loops the row at the sheet's fps
/// (idle bob); `animate: false` renders the first frame statically (portraits,
/// tests). Falls back to the idle row when [state] is missing on the sheet
/// (e.g. soot_shade has no run row).
class SpriteView extends StatefulWidget {
  final String spriteId;
  final String state;
  final double height;
  final bool flipX;
  final bool animate;
  const SpriteView(this.spriteId,
      {super.key,
      this.state = 'idle',
      required this.height,
      this.flipX = false,
      this.animate = true});

  @override
  State<SpriteView> createState() => _SpriteViewState();
}

class _SpriteViewState extends State<SpriteView>
    with SingleTickerProviderStateMixin {
  SpriteSheetDef? _def;
  SpriteRowDef? _row;
  ui.Image? _img;
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpriteView old) {
    super.didUpdateWidget(old);
    if (old.spriteId != widget.spriteId || old.state != widget.state) {
      _ctrl?.dispose();
      _ctrl = null;
      _def = null;
      _row = null;
      _img = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.spriteId;
    try {
      final meta = await SpriteMeta.load();
      final def = meta.sheet(id);
      if (def == null || !mounted) return;
      final img = await _loadSheetImage(def.assetPath);
      if (!mounted || widget.spriteId != id) return;
      final row = def.row(widget.state) ?? def.row('idle');
      setState(() {
        _def = def;
        _row = row;
        _img = img;
      });
      if (widget.animate && row != null && row.frames > 1) {
        _ctrl = AnimationController(
          vsync: this,
          duration:
              Duration(milliseconds: (row.frames * 1000 / def.fps).round()),
        )
          ..addListener(() => setState(() {}))
          ..repeat();
      }
    } catch (_) {/* missing asset: renders empty box, never crashes */}
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = _def;
    final row = _row;
    final img = _img;
    final aspect = def == null ? 1.0 : def.frameW / def.frameH;
    final size = Size(widget.height * aspect, widget.height);
    if (def == null || row == null || img == null) {
      return SizedBox.fromSize(size: size);
    }
    final frame = _ctrl == null
        ? 0
        : (_ctrl!.value * row.frames).floor().clamp(0, row.frames - 1);
    return CustomPaint(
      size: size,
      painter: _SpritePainter(
          img: img, def: def, row: row.row, frame: frame, flipX: widget.flipX),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image img;
  final SpriteSheetDef def;
  final int row;
  final int frame;
  final bool flipX;
  _SpritePainter(
      {required this.img,
      required this.def,
      required this.row,
      required this.frame,
      required this.flipX});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        (frame * def.frameW).toDouble(),
        (row * def.frameH).toDouble(),
        def.frameW.toDouble(),
        def.frameH.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.save();
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.frame != frame ||
      old.row != row ||
      old.img != img ||
      old.flipX != flipX;
}
