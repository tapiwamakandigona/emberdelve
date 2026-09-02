// tool/map_idle_probe_test.dart — one-off probe: what repaints on an IDLE
// map screen (no touch, intro sweep finished)? Perf book has map idle at
// 17.0 paints/frame [entrance_probe, 2026-09-01] — this names the painters.
// Reports, never asserts. flutter test tool/map_idle_probe_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('map idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tourSeenVersion = tourVersion
      ..tipsSeen.addAll(ContextTips.all);
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    c.startRun(character: 'kindler', seed: 6, boons: false, difficulty: 'easy');

    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: MapScreen(c)),
    );
    // Let the intro sweep and any entrance animation finish.
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Census: 120 idle frames.
    var frames = 0;
    var paints = 0;
    final byType = <String, int>{};
    debugOnProfilePaint = (RenderObject ro) {
      paints++;
      var t = ro.runtimeType.toString();
      if (ro is RenderCustomPaint) {
        t = '$t<${ro.painter?.runtimeType ?? ro.foregroundPainter?.runtimeType}>';
      }
      byType[t] = (byType[t] ?? 0) + 1;
    };
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    debugOnProfilePaint = null;

    final top = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print(
      'MAP IDLE frames=$frames paints=$paints '
      '(${(paints / frames).toStringAsFixed(1)}/frame)',
    );
    // ignore: avoid_print
    print(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({for (final e in top.take(20)) e.key: e.value}),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
