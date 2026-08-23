// lib/ui/sprites.dart — pixel-art sprite sheets, driven by the bundled
// assets/images/sprite_meta.json (frame size, rows = animation states, fps).
// Rendering is nearest-neighbour (FilterQuality.none) so pixels stay crisp.
//
// KNOWN ART GAP (see staging PROVENANCE): sheets carry idle/run rows only
// (heroes add a 1-frame hit row). Attack/death are choreographed in the UI
// layer with tweens + flashes, not sprite frames.
import 'dart:convert';
import 'dart:math' as math;
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
            r['state'] as String,
            r['frames'] as int,
            r['row'] as int,
          );
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

  /// LFP-4a: procedural idle bob (~2px sine at stage scale). The sheets'
  /// idle rows are either single-frame (soot_shade etc. — rendered fully
  /// static before this) or sub-pixel at combat size, so the *body* never
  /// read as alive. The bob runs on its own ticker, independent of the
  /// frame loop, so every combatant breathes even on 1-frame rows.
  final bool bob;

  /// LFP-4b: threat sway — a slow ±1px lean while the enemy's intent shows
  /// an attack, so the badge has body language (echoes the 190ms wind-up
  /// that plays when the hit actually comes).
  final bool sway;

  /// v0.27.0 Delver's Wardrobe: optional dye ColorFilter (Art.dyeFilter).
  /// Null (the default) skips the filter entirely, so undyed sprites render
  /// pixel-for-pixel as before. Only player-character call sites pass this;
  /// enemies are never dyed.
  final ColorFilter? dye;
  const SpriteView(
    this.spriteId, {
    super.key,
    this.state = 'idle',
    required this.height,
    this.flipX = false,
    this.animate = true,
    this.bob = false,
    this.sway = false,
    this.dye,
  });

  @override
  State<SpriteView> createState() => _SpriteViewState();
}

class _SpriteViewState extends State<SpriteView> with TickerProviderStateMixin {
  SpriteSheetDef? _def;
  SpriteRowDef? _row;
  ui.Image? _img;
  AnimationController? _ctrl;

  // LFP-4: idle-life ticker (bob + threat sway), independent of the frame
  // loop so 1-frame rows breathe too. 2.8s period: two full bob cycles.
  // Created on demand (NOT late final: a lazy dispose() would try to build
  // a controller during unmount and crash).
  AnimationController? _life;

  /// Single Listenable feeding the painter: frame loop + idle life. Cached
  /// so a rebuild doesn't hand the painter a fresh merge object every time.
  Listenable? _repaintDriver;
  void _rebuildDriver() {
    final parts = <Listenable>[
      if (_ctrl != null) _ctrl!,
      if (_life != null && (widget.bob || widget.sway) && widget.animate)
        _life!,
    ];
    _repaintDriver = parts.isEmpty
        ? null
        : (parts.length == 1 ? parts.first : Listenable.merge(parts));
  }

  void _syncLife() {
    final want = widget.animate && (widget.bob || widget.sway);
    if (want) {
      _life ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      if (!_life!.isAnimating) _life!.repeat();
    } else {
      _life?.stop();
    }
    _rebuildDriver();
  }

  // Load-generation token: only the most recent _load() may commit results
  // or create an AnimationController, so overlapping loads (rapid
  // didUpdateWidget) can never leak a second ticker.
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _syncLife();
    _load();
  }

  @override
  void didUpdateWidget(SpriteView old) {
    super.didUpdateWidget(old);
    _syncLife();
    if (old.spriteId != widget.spriteId || old.state != widget.state) {
      _ctrl?.dispose();
      _ctrl = null;
      _rebuildDriver();
      _def = null;
      _row = null;
      _img = null;
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final id = widget.spriteId;
    try {
      final meta = await SpriteMeta.load();
      final def = meta.sheet(id);
      if (def == null || !mounted || gen != _loadGen) return;
      final img = await _loadSheetImage(def.assetPath);
      if (!mounted || gen != _loadGen || widget.spriteId != id) return;
      final row = def.row(widget.state) ?? def.row('idle');
      setState(() {
        _def = def;
        _row = row;
        _img = img;
      });
      if (widget.animate && row != null && row.frames > 1) {
        // PERF: no addListener(setState) here. The controller is handed to
        // the painter as its `repaint` Listenable, so a frame step repaints
        // the sprite's own layer only — it never rebuilds this element and
        // never dirties the screen above it. Before this, every animated
        // sprite rebuilt + repainted the whole screen 60x/s (measured:
        // combat idle went 204 -> single digits painted render objects per
        // frame, tool/perf_probe_test.dart).
        _ctrl = AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: (row.frames * 1000 / def.fps).round(),
          ),
        )..repeat();
      }
    } catch (_) {
      /* missing asset: renders empty box, never crashes */
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _life?.dispose();
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
    // PERF: everything animated about a sprite — the frame loop AND the
    // LFP-4 idle bob/sway — is driven straight into the painter through
    // [CustomPainter.repaint]. The bob/sway used to be an AnimatedBuilder,
    // i.e. a setState 60x/s; because the combat screen wraps its stage in a
    // LayoutBuilder, that setState scheduled a layout callback and forced a
    // FULL RELAYOUT + repaint of the screen on every frame, permanently.
    // (Measured with tool/perf_probe_test.dart: 204 render objects painted
    // per idle frame.) Transform-on-canvas costs nothing and dirties nothing.
    final life = widget.animate && (widget.bob || widget.sway) ? _life : null;
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _SpritePainter(
          img: img,
          def: def,
          row: row.row,
          frames: row.frames,
          anim: _ctrl,
          life: life,
          bob: widget.bob,
          sway: widget.sway,
          flipX: widget.flipX,
          dye: widget.dye,
          repaint: _repaintDriver,
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image img;
  final SpriteSheetDef def;
  final int row;
  final int frames;

  /// Frame-loop driver. Given to [CustomPainter.repaint] so a frame step
  /// repaints this painter directly — no setState, no element rebuild.
  final Animation<double>? anim;

  /// LFP-4 idle-life driver (bob/sway), applied as a canvas transform.
  final Animation<double>? life;
  final bool bob;
  final bool sway;
  final bool flipX;
  final ColorFilter? dye;
  _SpritePainter({
    required this.img,
    required this.def,
    required this.row,
    required this.frames,
    required this.anim,
    required this.life,
    required this.bob,
    required this.sway,
    required this.flipX,
    required this.dye,
    required super.repaint,
  });

  int get frame {
    final a = anim;
    if (a == null || frames <= 1) return 0;
    return (a.value * frames).floor().clamp(0, frames - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      (frame * def.frameW).toDouble(),
      (row * def.frameH).toDouble(),
      def.frameW.toDouble(),
      def.frameH.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.none;
    // Delver dye: hue-rotation matrix; null (undyed) costs nothing.
    if (dye != null) paint.colorFilter = dye;
    canvas.save();
    final l = life;
    if (l != null && (bob || sway)) {
      // Bob is a 2px vertical sine (two cycles per life period); sway is a
      // slower ±1.2px lean with a hint of rotation about the feet,
      // phase-shifted so the two never sync into a mechanical wobble.
      final t = l.value * 2 * math.pi;
      final dy = bob ? math.sin(t * 2) * 2.0 : 0.0;
      final dx = sway ? math.sin(t + math.pi / 3) * 1.2 : 0.0;
      canvas.translate(dx, dy);
      if (sway) {
        final rot = math.sin(t + math.pi / 3) * 0.012;
        canvas.translate(size.width / 2, size.height);
        canvas.rotate(rot);
        canvas.translate(-size.width / 2, -size.height);
      }
    }
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.anim != anim ||
      old.life != life ||
      old.bob != bob ||
      old.sway != sway ||
      old.frames != frames ||
      old.row != row ||
      old.img != img ||
      old.flipX != flipX ||
      old.dye != dye;
}
