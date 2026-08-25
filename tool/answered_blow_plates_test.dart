// tool/answered_blow_plates_test.dart — screenshot plates for the v0.47.0
// response-puzzle intent badges (charge / counter / stagger). Not part of CI:
// run manually, then LOOK at the plates (DEMAND: UI changes get a critique).
//   flutter test tool/answered_blow_plates_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/ui/screens.dart';

const outDir = 'build/answered_blow_plates';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await icons.load();
    }
  }
}

final rootKey = GlobalKey();

Widget app(Widget child) => RepaintBoundary(
  key: rootKey,
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

Future<void> pumpFor(WidgetTester tester, int ms) async {
  var t = 0;
  while (t < ms) {
    await tester.pump(const Duration(milliseconds: 50));
    t += 50;
  }
}

Future<void> snap(WidgetTester tester, String name) async {
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final file = File('$outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $outDir/$name.png (${image!.width}x${image.height})');
}

/// Walk the real map to the first fight so the combat screen is the true
/// stage (a mid-map combatBegin renders a broken hybrid — first cut of these
/// plates did exactly that and critiqued an artifact).
Future<void> toFight(WidgetTester tester, GameController c) async {
  var guard = 0;
  while (guard++ < 40 && c.phase == 'map') {
    final map = c.state!['map'] as Map;
    final position = map['position'] as int;
    final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
    final nodes = (map['nodes'] as Map).cast<String, Map>();
    var pick = edges.first;
    for (final e in edges) {
      final kind = nodes['$e']!['kind'] as String;
      if (kind == 'fight' || kind == 'elite') {
        pick = e;
        break;
      }
    }
    c.apply({'type': 'choose_node', 'node': pick});
    await pumpFor(tester, 400);
  }
}

Future<void> plates(WidgetTester tester, String suffix) async {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all);
  await tester.pumpWidget(app(GameRoot(c)));
  await pumpFor(tester, 600);
  c.startRun(character: 'kindler', seed: 7, boons: false);
  await pumpFor(tester, 600);
  await toFight(tester, c);
  expect(c.phase, 'player_turn', reason: 'plates need a real fight');

  // Swap the live enemy's telegraph for each new kind — the true combat
  // stage, only the badge content differs.
  final enemy = c.state!['enemy'] as Map;
  for (final probe in [
    (<String, Object?>{'kind': 'charge', 'amount': 34, 'threshold': 9},
        'charge'),
    (<String, Object?>{'kind': 'counter', 'amount': 3}, 'counter'),
    (<String, Object?>{'kind': 'stagger', 'amount': 0}, 'stagger'),
    (<String, Object?>{'kind': 'attack_block', 'amount': 25, 'block': 18},
        'attack_block_ref'),
  ]) {
    enemy['intent'] = probe.$1;
    c.apply({'type': 'roll'}); // ticks the controller so the HUD rebuilds
    await pumpFor(tester, 700);
    await snap(tester, '${probe.$2}_$suffix');
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('badge plates 360x640', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(360, 640) * 2;
    addTearDown(tester.view.reset);
    await plates(tester, '360x640');
  });

  testWidgets('badge plates 320x568 at 1.3x', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(320, 568) * 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await plates(tester, '320x568_13');
  });
}
