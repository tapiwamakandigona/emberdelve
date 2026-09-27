// tool/kill_readout_frames_test.dart — review plates for the kill readout
// (experimental loop C0-03). NOT part of `flutter test` (lives in tool/):
// lands an exact kill and an overkill at phone sizes with the shipped fonts
// and precached art, and writes the kill frames to build/kill_readout/.
//   flutter test tool/kill_readout_frames_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/fx.dart';
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
    '320x640': Size(320, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final exact in [true, false]) {
    for (final e in sizes.entries) {
      final label = '${exact ? 'exact' : 'overkill'}_${e.key}';
      testWidgets('kill plates $label', (tester) async {
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
        await k.toFight(tester, c);
        await tester.tap(k.button('Roll'));
        for (var t = 0; t < 2000; t += 40) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        final rolled = (c.sim!.player['rolled'] as List).length;
        var die = 0, value = 0;
        for (var d = 1; d <= rolled; d++) {
          final r = resolveAssignment(
            player: c.sim!.player,
            enemy: c.sim!.enemy!,
            run: c.sim!.run,
            die: d,
            action: 'attack',
          );
          if (r.allowed && r.value >= 2) {
            die = d;
            value = r.value;
            break;
          }
        }
        c.sim!.enemy!['hp'] = exact ? value : value - 1;
        c.sim!.enemy!['block'] = 0;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await tester.pump();
        await tester.tap(
          find
              .byWidgetPredicate((w) => w is DieChip && w.value != null)
              .at(die - 1),
        );
        await tester.pump();
        await tester.tap(k.button('Attack'));
        for (var ms = 40; ms <= 1400; ms += 40) {
          await tester.pump(const Duration(milliseconds: 40));
          if (Platform.environment['DIAG'] != null) {
            final pops = find
                .byType(DamagePop)
                .evaluate()
                .map((e) => '${e.widget.key}')
                .join(',');
            // ignore: avoid_print
            print('DIAG $label t=$ms pops=[$pops] phase=${c.phase}');
          }
          if (const {360, 520, 720, 960, 1200}.contains(ms)) {
            await png(tester, key, 'build/kill_readout/${label}_t$ms.png');
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        for (var t = 0; t < 3000; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    }
  }
}
