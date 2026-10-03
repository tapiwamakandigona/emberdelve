// tool/victory_moment_frames_test.dart — review plates for the victory
// moment (experimental loop C4-01). NOT part of `flutter test` (lives in
// tool/). The scenario of test/victory_moment_test.dart: seed 6's opening
// roll is a 3-4-5 straight (STRAIGHT! + FREE REROLL NEXT TURN); 900 ms later
// a die is spent on Attack against a burning foe made a boss with exactly
// that many HP (FIXTURE), so the run-ending blow is an EXACT kill. With the
// shipped fonts and every PNG precached it writes frames counted from the
// Attack tap to build/victory_moment/<size>[_reduced]_t<ms>.png — the
// victory_<size>_t0600/t1200 plates the round-4 critic judged.
//   flutter test tool/victory_moment_frames_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/sim/assignment.dart';
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
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final reduced in const [false, true]) {
    for (final e in sizes.entries) {
      final name = '${e.key}${reduced ? '_reduced' : ''}';
      testWidgets('victory moment plates $name', (tester) async {
        tester.view.physicalSize = e.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        addTearDown(() => Motion.instance.update(setting: 'off'));
        Motion.instance.update(setting: reduced ? 'on' : 'off');
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
        c.startRun(
          character: 'kindler',
          boons: true,
          seed: 6,
          difficulty: 'easy',
        );
        c.apply({'type': 'choose_boon', 'index': 0});
        c.apply({'type': 'choose_node', 'node': 2});
        for (var t = 0; t < 2600; t += 40) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.tap(k.button('Roll'));
        for (var t = 0; t < 900; t += 40) {
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
        // FIXTURE: the run-ending EXACT blow on a burning boss.
        final map = c.sim!.map!;
        ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
        c.sim!.enemy!['boss'] = true;
        c.sim!.enemy!['hp'] = value;
        c.sim!.enemy!['block'] = 0;
        c.sim!.enemy!['burn'] = 3;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await tester.pump();
        final dice = find.byWidgetPredicate(
          (w) => w is DieChip && w.value != null,
        );
        await tester.tap(dice.at(die - 1));
        await tester.pump();
        await tester.tap(k.button('Attack'));
        for (var ms = 40; ms <= 1200; ms += 40) {
          await tester.pump(const Duration(milliseconds: 40));
          if (const {600, 640, 800, 1200}.contains(ms)) {
            await png(
              tester,
              key,
              'build/victory_moment/${name}_t${ms.toString().padLeft(4, '0')}.png',
            );
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        for (var t = 0; t < 4000; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    }
  }
}
