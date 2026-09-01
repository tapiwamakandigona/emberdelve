// lib/ui/warmup.dart — THE FIRST SPARK: Skia shader warm-up.
//
// THE STEADY RENDERER (1bb5a60f) pinned the engine to Skia for driver
// stability, which re-opens Skia's classic cost: GPU shader programs
// compile the first time a draw-op family is rasterized, mid-animation,
// on the device. On low-end phones that is a visible hitch exactly where
// this game shows off — the first SmolderIn sweep, the first ember glow,
// the first weapon flourish. Flutter ships NO default warm-up (the old
// DefaultShaderWarmUp was retired), so we hand PaintingBinding a scene
// that draws one small instance of every shader family this app actually
// uses, offscreen, during startup — moving compilation from animation
// time to boot time (see ShaderWarmUp docs).
//
// Families mirrored from real paint code (grep-audited 2026-09-01):
//   - LinearGradient fills + ShaderMask modulate (SmolderIn, panels,
//     widgets.dart bars, weapons)
//   - RadialGradient glows (fx.dart vignette/glow, combat stage pool)
//   - SweepGradient (weapons.dart rune ring)
//   - MaskFilter.blur normal-style (logo, weapons, widgets under-glow)
//   - Plain + stroked rects/rrects/circles/paths, saveLayer w/ opacity
//     (shake boundary composite, phase fades)
//   - drawImageRect @ FilterQuality.none, plain / matrix-ColorFilter
//     (dye) / ColorFilter.mode saveLayer composite (sprites, hit-flash)
//
// Kept intentionally small (~a dozen draws on a 100x100 canvas): warm-up
// runs once at boot; every draw must be onscreen within [size] to count.
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

class EmberShaderWarmUp extends ShaderWarmUp {
  const EmberShaderWarmUp();

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    const rect = Rect.fromLTWH(10, 10, 80, 80);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // 1. Linear gradient fill (panels, bars, SmolderIn's mask family).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0x66FF7A29), Color(0x00000000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // 2. Radial glow (ember pools, vignettes).
    canvas.drawCircle(
      const Offset(50, 50),
      36,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xAAFF9A3D), Color(0x00000000)],
        ).createShader(rect),
    );

    // 3. Sweep gradient (weapon rune ring).
    canvas.drawCircle(
      const Offset(50, 50),
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = const SweepGradient(
          colors: [Color(0xFFFF7A29), Color(0xFFE8C56A), Color(0xFFFF7A29)],
        ).createShader(rect),
    );

    // 4. Blur mask (glows and soft shadows).
    canvas.drawCircle(
      const Offset(50, 50),
      20,
      Paint()
        ..color = const Color(0x80FF7A29)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 5. Plain + stroked solids (the bulk of every screen).
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1E1826));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x33FF7A29),
    );
    final path = Path()
      ..moveTo(15, 80)
      ..quadraticBezierTo(50, 10, 85, 80);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE8C56A),
    );

    // 6. saveLayer composite with opacity (RepaintBoundary/fade blends).
    canvas.saveLayer(rect, Paint()..color = const Color(0x66FFFFFF));
    canvas.drawCircle(const Offset(50, 50), 12, Paint()..color = const Color(0xFFFF7A29));
    canvas.restore();

    // 7. Image sampling variants (2026-09-01 warmup audit): every sprite
    // draws through drawImageRect at FilterQuality.none, dyed player
    // sprites add a matrix ColorFilter (Art.dyeFilter), and the combat
    // hit-flash composites a ColorFilter.mode saveLayer over the sprite.
    // None of these pipelines were rehearsed — on the Skia renderer (the
    // shipped one: Impeller is disabled in the manifest) the FIRST sprite
    // frame and the FIRST hit therefore compiled shaders mid-combat.
    // The image is drawn on the spot; sub-frame cost, run once at boot.
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFFFF7A29),
    );
    final img = await rec.endRecording().toImage(4, 4);
    const src = Rect.fromLTWH(0, 0, 4, 4);
    // Plain pixel-art sample (every sprite, every frame).
    canvas.drawImageRect(
      img,
      src,
      rect,
      Paint()..filterQuality = FilterQuality.none,
    );
    // Dyed sample: identity hue matrix — same shader variant as any dye.
    canvas.drawImageRect(
      img,
      src,
      rect,
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
    );
    // Hit-flash composite: ColorFilter.mode saveLayer over an image draw.
    canvas.saveLayer(
      rect,
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0xFFFFFFFF),
          BlendMode.srcATop,
        ),
    );
    canvas.drawImageRect(
      img,
      src,
      rect,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
    img.dispose();
  }
}
