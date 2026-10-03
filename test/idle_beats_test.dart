// Idle beats (backlog C0-14): a heavy body that only breathes and a crawler
// that only side-steps still read as paused on a strip, because the whole
// sprite moves as one block. Once per idle loop each gets one short body
// action instead: heavies roll their shoulders (a lean about the feet and
// back), crawlers twitch (two quick wiggles during a held beat). The action
// is a window, not a constant wobble, so the rest of the loop stays calm.
// Presentation only; reduce motion still stops the life ticker entirely.
import 'dart:math' as math;

import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _n = 720;

List<double> _rot(IdleStyle style) => [
  for (var i = 0; i < _n; i++) idleLife(style, i / _n * 2 * math.pi).rot,
];

double _span(List<double> v) => v.reduce(math.max) - v.reduce(math.min);

/// Fraction of the loop during which the body is visibly turned.
double _activeShare(List<double> rot) =>
    rot.where((r) => r.abs() > 0.002).length / rot.length;

/// Horizontal extent of the opaque pixels (left, right) of [foe] idling as
/// it does on the combat stage, sampled every 100 ms over one 2.8 s loop,
/// rendered at 2x.
Future<({List<int> left, List<int> width})> _strip(
  WidgetTester tester,
  String foe,
) async {
  final def = enemies[foe]!;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 220,
            height: 160,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SpriteView(
                foe,
                height: 96,
                flipX: true,
                bob: true,
                idle: enemyIdleFor(foe, boss: def.boss, elite: def.elite),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final left = <int>[];
  final width = <int>[];
  for (var i = 0; i < 28; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final ro =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 2);
      final px = (await image.toByteData())!.buffer.asUint8List();
      var x0 = image.width, x1 = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (px[(y * image.width + x) * 4 + 3] > 16) {
            x0 = math.min(x0, x);
            x1 = math.max(x1, x);
          }
        }
      }
      left.add(x0);
      width.add(x1 - x0);
      image.dispose();
    });
  }
  await tester.pumpWidget(const SizedBox.shrink());
  return (left: left, width: width);
}

int _range(List<int> v) => v.reduce(math.max) - v.reduce(math.min);

void main() {
  tearDown(() => Motion.instance.reset());

  group('idle beat envelopes', () {
    test('heavies roll their shoulders once a loop, then settle', () {
      final rot = _rot(IdleStyle.heave);
      expect(_span(rot), greaterThanOrEqualTo(0.06), reason: 'a real lean');
      final share = _activeShare(rot);
      expect(share, greaterThan(0.08), reason: 'long enough to read');
      expect(share, lessThanOrEqualTo(0.2), reason: 'a beat, not a wobble');
    });

    test('crawlers twitch once a loop, quick and low', () {
      final rot = _rot(IdleStyle.scuttle);
      expect(_span(rot), greaterThanOrEqualTo(0.08), reason: 'a real twitch');
      final share = _activeShare(rot);
      expect(share, greaterThan(0.04), reason: 'long enough to read');
      expect(share, lessThanOrEqualTo(0.12), reason: 'a twitch is quick');
    });

    test('plain breathers and hovering bodies are unchanged', () {
      for (var i = 0; i < 64; i++) {
        final p = idleLife(IdleStyle.breathe, i * 0.1);
        expect([p.dx, p.dy, p.rot, p.scaleY], [0.0, 0.0, 0.0, 1.0]);
      }
    });
  });

  testWidgets('the brute visibly shifts its bulk, not just its height', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    Motion.instance.update(setting: 'off');
    final s = await _strip(tester, 'slag_brute');
    // Before: the left edge never moved (0 px over the whole loop).
    expect(_range(s.left), greaterThanOrEqualTo(3), reason: '${s.left}');
  });

  testWidgets('the crawler twitches its body, not just slides it', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    Motion.instance.update(setting: 'off');
    final s = await _strip(tester, 'flue_crawler');
    // A pure side-step keeps the footprint width; a twitch turns the body.
    expect(_range(s.width), greaterThanOrEqualTo(3), reason: '${s.width}');
  });

  testWidgets('reduce motion keeps the idling body perfectly still', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    Motion.instance.update(setting: 'on');
    for (final foe in ['slag_brute', 'flue_crawler']) {
      final s = await _strip(tester, foe);
      expect(_range(s.left), 0, reason: foe);
      expect(_range(s.width), 0, reason: foe);
    }
  });
}
