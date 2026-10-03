// test/damage_number_outline_test.dart — experimental polish loop, critic
// round 2 issue C2-04: the yellow damage number was drawn straight onto the
// foe's pure-white hit-flash body (about 1.5:1), so the most important
// number of the hit was least legible on the exact frame it appeared.
//
// This renders the real DamagePop over a pure-white backdrop (the flash
// silhouette's worst case) and measures, in the captured pixels, the
// contrast between the number's gold fill and the ring of pixels right
// around its glyphs (1 dp out). It must be at least 3:1 — with motion and
// under Reduce Motion, for a hit number and for BLOCKED.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' show loadRealFonts;

double _lin(int c) {
  final s = c / 255.0;
  return s <= 0.03928
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(int r, int g, int b) =>
    0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);

/// Contrast of the number's fill against the pixels 1 dp around its glyphs.
Future<({double ratio, int fill, int ring})> measure(
  WidgetTester tester, {
  required bool blocked,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: 160,
            height: 120,
            color: Colors.white, // the hit-flash silhouette
            alignment: Alignment.center,
            child: DamagePop(amount: 6, blocked: blocked, onDone: () {}),
          ),
        ),
      ),
    ),
  );
  // Past the pop-in overshoot, before the fade: the number at full ink.
  await tester.pump(const Duration(milliseconds: 160));
  const dpr = 2.0;
  final bytes = (await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    return data!;
  }))!;
  const w = 320, h = 240;
  final want = blocked ? EmberColors.block : EmberColors.gold;
  int ch(double v) => (v * 255).round();
  final wr = ch(want.r), wg = ch(want.g), wb = ch(want.b);
  bool isFill(int x, int y) {
    final i = (y * w + x) * 4;
    final r = bytes.getUint8(i), g = bytes.getUint8(i + 1);
    final b = bytes.getUint8(i + 2);
    return (r - wr).abs() + (g - wg).abs() + (b - wb).abs() < 30;
  }

  final fill = <int>{};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (isFill(x, y)) fill.add(y * w + x);
    }
  }
  final ring = <double>[];
  const step = 2; // 1 dp at dpr 2
  for (final p in fill) {
    final x = p % w, y = p ~/ w;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx * step, ny = y + dy * step;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final q = ny * w + nx;
      if (fill.contains(q)) continue;
      final i = q * 4;
      ring.add(
        _lum(bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)),
      );
    }
  }
  ring.sort();
  // The median ring pixel: what the eye reads as "around the number".
  final ringLum = ring.isEmpty ? 1.0 : ring[ring.length ~/ 2];
  final fillLum = _lum(wr, wg, wb);
  final hi = math.max(fillLum, ringLum), lo = math.min(fillLum, ringLum);
  return (
    ratio: (hi + 0.05) / (lo + 0.05),
    fill: fill.length,
    ring: ring.length,
  );
}

void main() {
  setUpAll(loadRealFonts);
  for (final motion in ['off', 'on']) {
    for (final blocked in [false, true]) {
      testWidgets('damage number reads >= 3:1 on a white flash '
          '(reduce motion $motion, ${blocked ? 'BLOCKED' : '-6'})', (
        tester,
      ) async {
        Motion.instance.update(setting: motion);
        addTearDown(() => Motion.instance.update(setting: 'off'));
        final m = await measure(tester, blocked: blocked);
        expect(m.fill, greaterThan(40), reason: 'the number was not found');
        expect(
          m.ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              'fill vs 1 dp ring contrast ${m.ratio.toStringAsFixed(2)}:1 '
              '(${m.fill} fill px, ${m.ring} ring samples)',
        );
        await tester.pump(const Duration(milliseconds: 700));
      });
    }
  }
}
