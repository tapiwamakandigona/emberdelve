// tool/idle_census_probe_test.dart — probe: painter census on IDLE title,
// rest and shop screens (the last un-probed screens). Reports, never asserts.
//   flutter test tool/idle_census_probe_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
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

GameController seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  return c;
}

Future<void> census(
  WidgetTester tester,
  String name,
  Widget screen, {
  int warmup = 300,
}) async {
  await tester.pumpWidget(MaterialApp(theme: buildEmberTheme(), home: screen));
  for (var i = 0; i < warmup; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
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
    '$name IDLE frames=$frames paints=$paints '
    '(${(paints / frames).toStringAsFixed(1)}/frame)',
  );
  // ignore: avoid_print
  print(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({for (final e in top.take(16)) e.key: e.value}),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}

Future<bool> driveTo(GameController c, String phase, {int max = 4000}) async {
  var guard = 0;
  while (c.state!['phase'] != phase && guard++ < max) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) return false;
    c.apply(cmd);
  }
  return c.state!['phase'] == phase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('title idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await census(tester, 'TITLE', TitleScreen(c));
  });

  testWidgets('rest idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    c.startRun(character: 'kindler', seed: 6, boons: false, difficulty: 'easy');
    final ok = await driveTo(c, 'rest');
    // ignore: avoid_print
    print('rest reached: $ok (phase ${c.state!['phase']})');
    if (ok) await census(tester, 'REST', RestScreen(c));
  });

  testWidgets('shop idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    c.startRun(character: 'kindler', seed: 7, boons: false, difficulty: 'easy');
    final ok = await driveTo(c, 'shop');
    // ignore: avoid_print
    print('shop reached: $ok (phase ${c.state!['phase']})');
    if (ok) await census(tester, 'SHOP', ShopScreen(c));
  });

  // v0.180.0: summary got a pinned primary footer and the roster lost its
  // dead buttons — confirm neither screen paints while idle.
  testWidgets('summary idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    c.startRun(
      character: 'kindler',
      seed: 7,
      boons: false,
      difficulty: 'normal',
    );
    var guard = 0;
    while (guard++ < 4000 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    // ignore: avoid_print
    print('summary reached: ${c.phase}');
    await census(tester, 'SUMMARY', GameRoot(c), warmup: 400);
  });

  testWidgets('character idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await census(tester, 'CHARACTER', CharacterScreen(c), warmup: 400);
  });
}
