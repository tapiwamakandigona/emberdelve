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
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'combat_articulation.dart';
import 'combat_pose.dart';
import 'motion.dart';

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

  /// v0.183.0 Bodies in the Fight: where the forward hand sits on the idle
  /// frame, as fractions of the frame (x right, y down). The combat stage
  /// pins the weapon's grip here instead of one shared roster offset.
  /// Null on sheets that never hold anything (enemies).
  final Offset? hand;
  const SpriteSheetDef({
    required this.id,
    required this.assetPath,
    required this.frameW,
    required this.frameH,
    required this.rows,
    required this.fps,
    this.hand,
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

  /// Synchronous cache read (v0.177.0 The Banked Coals): non-null once
  /// [load] has completed. Lets SpriteView commit warm sheets without a
  /// frame of empty box.
  static SpriteMeta? get cachedOrNull => _cached;

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
        final hand = e['hand'] as List?;
        out[id] = SpriteSheetDef(
          id: id,
          assetPath: 'assets/images/$dir/$id.png',
          frameW: e['frame_w'] as int,
          frameH: e['frame_h'] as int,
          rows: rows,
          fps: e['fps'] as int? ?? 8,
          hand: hand == null || hand.length < 2
              ? null
              : Offset(
                  (hand[0] as num).toDouble(),
                  (hand[1] as num).toDouble(),
                ),
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

/// v0.177.0 The Banked Coals: decode every bundled sheet into the cache.
/// ~99 KB of pixel-art PNG on disk; a few MB decoded. Called once after
/// the first frame so the title paints instantly and everything after —
/// picker cards, map nodes, first combat — renders its sprite on its
/// FIRST frame instead of popping in a decode later.
Future<void> warmSpriteSheets() async {
  final meta = await SpriteMeta.load();
  await Future.wait([
    for (final def in meta.enemies.values) _loadSheetImage(def.assetPath),
    for (final def in meta.characters.values) _loadSheetImage(def.assetPath),
  ]);
  for (final def in meta.characters.values) {
    if (CombatRig.forId(def.id) != null) {
      _rigImages(def, _imageCache[def.assetPath]!);
    }
  }
}

@visibleForTesting
bool debugSpriteSheetCached(String id) {
  final def = SpriteMeta.cachedOrNull?.sheet(id);
  return def != null && _imageCache.containsKey(def.assetPath);
}

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

// Tiny combat-only cutouts, cached once per native sheet (11 x 32 x 40).
// Cropping on load avoids per-frame masking/saveLayers. The small overlapping
// joint caps reuse source pixels and leave portrait rows untouched.
final Map<String, List<ui.Image>> _rigImageCache = {};

/// Explicit decoded budget for the whole roster's source-pixel cutouts.
/// Each cached part is 32x40 RGBA; no allocation is performed per frame.
@visibleForTesting
int get debugCombatRigCacheBytes => _rigImageCache.values.fold(
  0, (total, parts) => total + parts.fold(0, (n, p) => n + p.width * p.height * 4),
);

List<ui.Image> _rigImages(SpriteSheetDef def, ui.Image source) {
  return _rigImageCache.putIfAbsent(def.assetPath, () {
    final rig = CombatRig.forId(def.id)!;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    return [
      for (final part in RigPart.values)
        () {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          for (var y = 0; y < 40; y++) {
            var x = 0;
            while (x < 32) {
              if (!rig.includesPixel(part, x, y)) {
                x++;
                continue;
              }
              final start = x++;
              while (x < 32 && rig.includesPixel(part, x, y)) {
                x++;
              }
              final rect = Rect.fromLTWH(
                start.toDouble(),
                y.toDouble(),
                (x - start).toDouble(),
                1,
              );
              canvas.drawImageRect(
                source,
                rect,
                rect,
                paint..color = Colors.white,
              );
            }
          }
          final picture = recorder.endRecording();
          final image = picture.toImageSync(32, 40);
          picture.dispose();
          return image;
        }(),
    ];
  });
}

/// The same native gauntlet is painted over the held tool so its shaft
/// passes THROUGH the grip, not in front of a hand-shaped decoration.
class SpriteGripOverlay extends StatelessWidget {
  final String spriteId;
  final ValueListenable<CombatRigSample> articulation;
  final ColorFilter? dye;
  const SpriteGripOverlay(
    this.spriteId, {
    super.key,
    required this.articulation,
    this.dye,
  });

  @override
  Widget build(BuildContext context) {
    final def = SpriteMeta.cachedOrNull?.sheet(spriteId);
    final images = def == null ? null : _rigImageCache[def.assetPath];
    if (images == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GripPainter(images[RigPart.hand.index], articulation, dye),
        ),
      ),
    );
  }
}

class _GripPainter extends CustomPainter {
  final ui.Image image;
  final ValueListenable<CombatRigSample> articulation;
  final ColorFilter? dye;
  late final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = dye;
  _GripPainter(this.image, this.articulation, this.dye)
    : super(repaint: articulation);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / 40);
    canvas.transform(articulation.value.part(RigPart.hand).matrix);
    canvas.drawImage(image, Offset.zero, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GripPainter old) =>
      old.image != image || old.articulation != articulation || old.dye != dye;
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

  /// v0.183.0 Bodies in the Fight: how hurt this body is. Drives breathing
  /// rate/amplitude, the low-health tremor and the wound marks painted onto
  /// the sprite's own pixels. [Condition.fresh] renders exactly as before.
  final Condition condition;

  /// What this body bleeds (colours the wound marks). Ignored while fresh.
  final Ichor ichor;

  /// Comfort setting: hide bloody marks without resetting the body's
  /// condition. Breathing, tremor, posture and pallor remain informative.
  final bool showWounds;

  /// Combat-only first-cell joint rig. Its clock replaces both local loops.
  /// Null retains the original sheet renderer for portraits/other delvers.
  final ValueListenable<CombatRigSample>? articulation;
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
    this.condition = Condition.fresh,
    this.ichor = Ichor.blood,
    this.showWounds = true,
    this.articulation,
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
      if (widget.articulation != null) widget.articulation!,
      if (_ctrl != null && widget.articulation == null) _ctrl!,
      if (_life != null &&
          widget.articulation == null &&
          (widget.bob || widget.sway) &&
          widget.animate)
        _life!,
    ];
    _repaintDriver = parts.isEmpty
        ? null
        : (parts.length == 1 ? parts.first : Listenable.merge(parts));
  }

  void _syncLife() {
    // Reduce motion (2026-09-01 stillness audit): bob/sway is a decorative
    // displacement loop — under reduce the life ticker never runs and the
    // sprite holds its neutral pose (the sheet frame loop, if any, is a
    // separate clock and unaffected).
    final want =
        widget.animate &&
        widget.articulation == null &&
        (widget.bob || widget.sway) &&
        !Motion.instance.reduced;
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

  /// Reduce motion also parks the sheet frame loop on frame 0 (the same
  /// pose portraits render) — the repeating clock repaints the layer every
  /// frame even when the visible sheet frame only changes a few times a
  /// second, so under reduce it must not run at all.
  void _syncFrameLoop() {
    final c = _ctrl;
    if (c == null) return;
    if (Motion.instance.reduced || widget.articulation != null) {
      c
        ..stop()
        ..value = 0;
    } else if (!c.isAnimating) {
      c.repeat();
    }
  }

  void _onMotion() {
    if (!mounted) return;
    setState(_syncLife);
    _syncFrameLoop();
  }

  @override
  void initState() {
    super.initState();
    Motion.instance.addListener(_onMotion);
    _syncLife();
    _load();
  }

  @override
  void didUpdateWidget(SpriteView old) {
    super.didUpdateWidget(old);
    _syncLife();
    if (old.spriteId != widget.spriteId ||
        old.state != widget.state ||
        old.articulation != widget.articulation) {
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
    // v0.177.0 The Banked Coals: warm-cache fast path. When the meta and
    // the sheet are already decoded, commit synchronously — no setState
    // needed (initState runs before the first build; didUpdateWidget is
    // already inside a rebuild) and no empty-box frame is ever shown.
    final warmMeta = SpriteMeta.cachedOrNull;
    if (warmMeta != null) {
      final def = warmMeta.sheet(id);
      final img = def == null ? null : _imageCache[def.assetPath];
      if (def != null && img != null) {
        if (widget.articulation != null) _rigImages(def, img);
        final row = def.row(widget.state) ?? def.row('idle');
        _def = def;
        _row = row;
        _img = img;
        if (widget.animate &&
            widget.articulation == null &&
            row != null &&
            row.frames > 1) {
          _ctrl = AnimationController(
            vsync: this,
            duration: Duration(
              milliseconds: (row.frames * 1000 / def.fps).round(),
            ),
          );
          _syncFrameLoop();
          _rebuildDriver();
        }
        return;
      }
    }
    try {
      final meta = await SpriteMeta.load();
      final def = meta.sheet(id);
      if (def == null || !mounted || gen != _loadGen) return;
      final img = await _loadSheetImage(def.assetPath);
      if (!mounted || gen != _loadGen || widget.spriteId != id) return;
      final row = def.row(widget.state) ?? def.row('idle');
      if (widget.articulation != null) _rigImages(def, img);
      setState(() {
        _def = def;
        _row = row;
        _img = img;
      });
      if (widget.animate &&
          widget.articulation == null &&
          row != null &&
          row.frames > 1) {
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
        );
        _syncFrameLoop();
        // v0.177.0 fix: the driver was built in initState, BEFORE this
        // controller existed, and never rebuilt — so the frame loop ticked
        // into a painter that never repainted. Anywhere without the bob
        // ticker (title hearth, map nodes, codex cards) froze on frame 0.
        _rebuildDriver();
      }
    } catch (_) {
      /* missing asset: renders empty box, never crashes */
    }
  }

  @override
  void dispose() {
    Motion.instance.removeListener(_onMotion);
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
          condition: widget.condition,
          ichor: widget.ichor,
          showWounds: widget.showWounds,
          articulation: widget.articulation,
          rigImages: widget.articulation == null
              ? null
              : _rigImageCache[def.assetPath],
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
  final Condition condition;
  final Ichor ichor;
  final bool showWounds;
  final ValueListenable<CombatRigSample>? articulation;
  final List<ui.Image>? rigImages;
  // Zero-alloc hot path (2026-09-01): this painter repaints at 60fps for
  // every idling sprite, and the painter INSTANCE survives across frames
  // (repaint rides the listenable, not a rebuild) — so the Paint is built
  // once here, not once per frame. `dye` is final, so the filter never
  // needs re-setting.
  late final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = dye;

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
    this.condition = Condition.fresh,
    this.ichor = Ichor.blood,
    this.showWounds = true,
    this.articulation,
    this.rigImages,
    required super.repaint,
  });

  /// Wound paint, built lazily (most sprites on screen are unhurt).
  Paint? _woundPaint;

  int get frame {
    final a = anim;
    if (a == null || frames <= 1) return 0;
    return (a.value * frames).floor().clamp(0, frames - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sample = articulation?.value;
    final images = rigImages;
    if (sample != null && images != null) {
      _paintRig(canvas, size, sample, images);
      return;
    }
    final src = Rect.fromLTWH(
      (frame * def.frameW).toDouble(),
      (row * def.frameH).toDouble(),
      def.frameW.toDouble(),
      def.frameH.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    final l = life;
    final cond = condition;
    if (l != null && (bob || sway)) {
      // Bob is a 2px vertical sine (two cycles per life period); sway is a
      // slower ±1.2px lean with a hint of rotation about the feet,
      // phase-shifted so the two never sync into a mechanical wobble.
      //
      // Bodies in the Fight: breathing is the bob. A hurt body breathes
      // faster (whole extra cycles per period, so the loop never seams)
      // and deeper — the shoulders visibly heave — and below a quarter
      // health the whole frame carries a fine tremor.
      final t = l.value * 2 * math.pi;
      final cycles = bob ? (2 * cond.breathRate).round() : 2;
      final breath = math.sin(t * cycles);
      final dy = bob ? breath * 2.0 * cond.breathAmp : 0.0;
      final tremor = cond.tremor;
      final jitter = tremor > 0 ? math.sin(t * 41.0) * tremor : 0.0;
      final dx = (sway ? math.sin(t + math.pi / 3) * 1.2 : 0.0) + jitter;
      canvas.translate(dx, dy);
      if (sway) {
        final rot = math.sin(t + math.pi / 3) * 0.012;
        canvas.translate(size.width / 2, size.height);
        canvas.rotate(rot);
        canvas.translate(-size.width / 2, -size.height);
      }
      if (bob && cond.hurt > 0.02) {
        // Heave: the chest rises and falls about the feet.
        final heave = 1.0 + breath * 0.012 * cond.breathAmp;
        canvas.translate(size.width / 2, size.height);
        canvas.scale(1.0, heave);
        canvas.translate(-size.width / 2, -size.height);
      }
    }
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final wounds = showWounds ? cond.wounds : 0;
    if (wounds == 0) {
      canvas.drawImageRect(img, src, dst, _paint);
    } else {
      // Wounds are painted INTO the body: the sprite is drawn into a layer
      // and the marks composite with srcATop, so they land on cloth and
      // skin only, never on the transparent surround. This is the one
      // saveLayer in the sprite path and it only exists while hurt.
      canvas.saveLayer(dst, Paint());
      canvas.drawImageRect(img, src, dst, _paint);
      _paintWounds(canvas, size, wounds);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintRig(
    Canvas canvas,
    Size size,
    CombatRigSample sample,
    List<ui.Image> images,
  ) {
    canvas.save();
    canvas.scale(size.height / 40);
    final wounds = showWounds ? condition.wounds : 0;
    if (wounds > 0) {
      canvas.saveLayer(const Rect.fromLTWH(-16, -16, 72, 72), Paint());
    }
    for (final part in RigPart.values) {
      canvas.save();
      canvas.transform(sample.part(part).matrix);
      canvas.drawImage(images[part.index], Offset.zero, _paint);
      canvas.restore();
    }
    if (wounds > 0) {
      // Marks ride the chest transform and are clipped into the composite
      // source pixels. Blood off skips this layer, not the rig/condition.
      canvas.save();
      canvas.transform(sample.part(RigPart.torso).matrix);
      _paintWounds(canvas, const Size(32, 40), wounds);
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintWounds(Canvas canvas, Size size, int wounds) {
    final p = _woundPaint ??= Paint()..blendMode = BlendMode.srcATop;
    final (core, rim) = _ichorColors(ichor);
    for (var i = 0; i < wounds && i < woundSpots.length; i++) {
      final w = woundSpots[i];
      final c = Offset(w.x * size.width, w.y * size.height);
      final r = w.r * size.height;
      // Three overlapping dabs make an irregular blot; a thin drip below
      // reads as fresh. Rim first (darker), core over it.
      p.color = rim;
      canvas.drawCircle(c, r, p);
      canvas.drawCircle(c.translate(r * 0.55, r * 0.3), r * 0.7, p);
      canvas.drawCircle(c.translate(-r * 0.45, r * 0.4), r * 0.6, p);
      p.color = core;
      canvas.drawCircle(c.translate(r * 0.1, r * 0.1), r * 0.55, p);
      // Drip: longer on the older (lower-index) wounds.
      final drip = r * (1.6 + (wounds - i) * 0.5);
      canvas.drawRect(
        Rect.fromLTWH(c.dx - r * 0.18, c.dy + r * 0.5, r * 0.36, drip),
        p,
      );
    }
  }

  static (Color, Color) _ichorColors(Ichor ichor) => switch (ichor) {
    Ichor.blood => (const Color(0xFF8C1616), const Color(0xFF4A0A0A)),
    Ichor.ember => (const Color(0xFFFF8A2C), const Color(0xFF9A3A0C)),
    Ichor.soot => (const Color(0xFF3A3040), const Color(0xFF15101C)),
    Ichor.ichor => (const Color(0xFF8AA82E), const Color(0xFF3F5414)),
  };

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
      old.dye != dye ||
      old.condition.wounds != condition.wounds ||
      old.condition.hurt != condition.hurt ||
      old.showWounds != showWounds ||
      old.articulation != articulation ||
      old.ichor != ichor;
}
