// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/cvd_plates_test.dart — colorblind-audit plates (v0.22.0 candidate).
// Not part of CI.
//
//   flutter test tool/cvd_plates_test.dart
//
// Captures the four surfaces where red/green carries meaning, at 360x640:
//   cvd_combat_intent — enemy intent badges + HP bars mid-fight
//   cvd_map           — node medallions (reachable vs not)
//   cvd_shop          — heal (success-green) card
//   cvd_ledger        — success-green stat icons
// A Python pass then applies protanopia/deuteranopia/tritanopia matrices;
// the critique judges whether meaning survives without hue.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';

const outDir = 'build/cvd_plates';
const shotSize = Size(360, 640);

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
  final end = ms;
  var t = 0;
  while (t < end) {
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

void main() {
  setUpAll(loadRealFonts);

  testWidgets('cvd plates', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = shotSize * 2;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tipsSeen.addAll(ContextTips.all);

    await tester.pumpWidget(app(GameRoot(c)));
    await pumpFor(tester, 600);

    c.startRun(character: 'kindler', seed: 7, boons: false);
    await pumpFor(tester, 900);
    if (c.phase == 'map') await snap(tester, 'cvd_map');

    // Walk to the first fight and the first shop (store-shots vocabulary).
    var guard = 0;
    var shotCombat = false, shotShop = false;
    while (guard++ < 60 && c.phase != null && !(shotCombat && shotShop)) {
      final phase = c.phase;
      if (phase == 'map') {
        final map = c.state!['map'] as Map;
        final position = map['position'] as int;
        final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        var pick = edges.first;
        for (final e in edges) {
          final kind = nodes['$e']!['kind'];
          if (!shotCombat && (kind == 'combat' || kind == 'elite')) {
            pick = e;
            break;
          }
          if (shotCombat && !shotShop && kind == 'shop') pick = e;
        }
        c.apply({'type': 'choose_node', 'node': pick});
        await pumpFor(tester, 900);
      } else if (phase == 'player_turn') {
        c.apply({'type': 'roll'});
        await pumpFor(tester, 2200); // tumble settles, intent visible
        if (!shotCombat) {
          await snap(tester, 'cvd_combat_intent');
          shotCombat = true;
        }
        final player = c.state!['player'] as Map;
        final n = (player['dice'] as List).length;
        for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
          c.apply({
            'type': 'assign',
            'die': i,
            'action': i.isEven ? 'block' : 'attack',
          });
        }
        await pumpFor(tester, 400);
        if (c.phase == 'player_turn') {
          c.apply({'type': 'end_turn'});
          await pumpFor(tester, 1400);
        }
      } else if (phase == 'reward') {
        await pumpFor(tester, 300);
        c.apply({'type': 'choose_reward', 'index': 0});
        await pumpFor(tester, 300);
      } else if (phase == 'shop') {
        await pumpFor(tester, 700);
        if (!shotShop) {
          await snap(tester, 'cvd_shop');
          shotShop = true;
        }
        c.apply({'type': 'leave_shop'});
        await pumpFor(tester, 300);
      } else if (phase == 'rest') {
        c.apply({'type': 'rest'});
        await pumpFor(tester, 300);
      } else if (phase == 'event') {
        await pumpFor(tester, 300);
        c.apply({'type': 'event_choose', 'option': 0});
        await pumpFor(tester, 300);
      } else {
        break;
      }
    }

    // Ledger (success-green stat icons).
    c.meta
      ..exactKills = 31
      ..runsPlayed = 23
      ..runsWon = 9;
    await tester.pumpWidget(app(LedgerScreen(c)));
    await pumpFor(tester, 600);
    await snap(tester, 'cvd_ledger');
  });
}
