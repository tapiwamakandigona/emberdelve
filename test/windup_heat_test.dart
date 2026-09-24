// Wind-up heat (2026-09-24 fix). The enemy's wind-up is meant to read as a
// heat shift ON THE BODY. It used to be an AnimatedContainer
// foregroundDecoration with a srcATop colour: srcATop composites against
// whatever is already on the canvas, so the whole combatant box — stage
// background included — went translucent red on every enemy wind-up (seen in
// real-render captures at 741b439). This test samples actual rendered pixels:
// the body must still warm up, the empty frame area above its head must not.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

const _foeKey = ValueKey('enemy-flue_crawler');

/// Median redness (R minus mean of G and B) over [block] of [rgba].
double _redness(ByteData rgba, int width, Rect block) {
  final v = <double>[];
  for (var y = block.top.round(); y < block.bottom.round(); y++) {
    for (var x = block.left.round(); x < block.right.round(); x++) {
      final o = (y * width + x) * 4;
      final r = rgba.getUint8(o).toDouble();
      final g = rgba.getUint8(o + 1).toDouble();
      final b = rgba.getUint8(o + 2).toDouble();
      v.add(r - (g + b) / 2);
    }
  }
  v.sort();
  return v[v.length ~/ 2];
}

void main() {
  tearDown(() => Motion.instance.reset());

  testWidgets('the wind-up heats the foe, not a box around it', (tester) async {
    await fixture.intoFight(tester);
    await tester.tap(fixture.button('Roll'));
    await fixture.pumpFor(tester, 1800);

    // The largest repaint boundary above the foe holds the stage background,
    // so a blend leaking outside the body shows up in its pixels.
    final boundaries =
        find
            .ancestor(
              of: find.byKey(_foeKey),
              matching: find.byType(RepaintBoundary),
            )
            .evaluate()
            .map((e) => e.renderObject! as RenderRepaintBoundary)
            .toList()
          ..sort(
            (a, b) => (b.size.width * b.size.height).compareTo(
              a.size.width * a.size.height,
            ),
          );
    final boundary = boundaries.first;

    Future<(double body, double empty)> sample() async {
      final foe = tester.getRect(find.byKey(_foeKey));
      final origin = boundary.localToGlobal(Offset.zero);
      final r = foe.shift(-origin);
      // flue_crawler's frame: the top 6 of 16 art rows are empty; the body
      // fills the lower half. Sample well inside each zone.
      final empty = Rect.fromLTRB(
        r.left + r.width * 0.40,
        r.top + r.height * 0.06,
        r.left + r.width * 0.60,
        r.top + r.height * 0.20,
      );
      final body = Rect.fromLTRB(
        r.left + r.width * 0.40,
        r.top + r.height * 0.55,
        r.left + r.width * 0.60,
        r.top + r.height * 0.75,
      );
      late ByteData data;
      late int width;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        width = image.width;
        data = (await image.toByteData())!;
        image.dispose();
      });
      return (_redness(data, width, body), _redness(data, width, empty));
    }

    final (body0, empty0) = await sample();
    await tester.tap(fixture.button('End turn'));
    var bodyRise = 0.0;
    var emptyRise = 0.0;
    for (var t = 0; t < 1000; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(_foeKey).evaluate().isEmpty) continue;
      final (body, empty) = await sample();
      if (body - body0 > bodyRise) bodyRise = body - body0;
      if (empty - empty0 > emptyRise) emptyRise = empty - empty0;
    }
    expect(bodyRise, greaterThan(10), reason: 'the body heats on the wind-up');
    expect(
      emptyRise,
      lessThan(6),
      reason: 'no translucent red box over the stage around the foe',
    );

    await fixture.pumpFor(tester, 2600);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.pumpFor(tester, 2200);
  });
}
