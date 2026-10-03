// tool/callout_lane_frames_test.dart — review plates for the call-out lanes
// (experimental loop C0-03 + C1-02). NOT part of `flutter test` (lives in
// tool/): seed 6's opening roll is a 3-4-5 straight, so ROLL fires
// "STRAIGHT!" and "FREE REROLL NEXT TURN" at once; 400 ms later a die is
// spent on Attack and tapped again ("ALREADY ASSIGNED"), a third, later
// call-out. With the shipped fonts and precached art it writes frames from
// the ROLL tap to build/callout_lanes/<size>_t<ms>.png — the plate-026
// equivalent the C0-03 acceptance asks for.
//   flutter test tool/callout_lane_frames_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/kill_readout_test.dart' as k;

Future<void> png(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> toFight(WidgetTester tester, GameController c) async {
  c.startRun(character: 'kindler', boons: true, seed: 6, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  for (var t = 0; t < 2600; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUpAll(() async {
    await k.loadRealFonts();
    final root = Platform.environment['FLUTTER_ROOT'];
    final f = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
          .load();
    }
  });
  const sizes = {
    '320x568': Size(320, 568),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final e in sizes.entries) {
    testWidgets('call-out lane plates ${e.key}', (tester) async {
      tester.view.physicalSize = e.value * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'off');
      final c = k.makeController();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: GameRoot(c),
          ),
        ),
      );
      await tester.runAsync(() async {
        await warmSpriteSheets();
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final context = tester.element(find.byType(MaterialApp));
        for (final a in manifest.listAssets().where(
          (a) => a.endsWith('.png'),
        )) {
          await precacheImage(AssetImage(a), context);
        }
      });
      await toFight(tester, c);
      await tester.tap(k.button('Roll'));
      var tapped = false;
      for (var ms = 40; ms <= 4400; ms += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        if (!tapped && ms >= 1000) {
          tapped = true;
          final dice = find.byWidgetPredicate(
            (w) => w is DieChip && w.value != null,
          );
          await tester.tap(dice.first);
          await tester.pump();
          await tester.tap(k.button('Attack'));
          await tester.pump(const Duration(milliseconds: 40));
          await tester.tap(dice.first, warnIfMissed: false);
        }
        if (const {800, 1400, 2000, 2800, 3600}.contains(ms)) {
          await png(tester, key, 'build/callout_lanes/${e.key}_t$ms.png');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      for (var t = 0; t < 3000; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  }
}
