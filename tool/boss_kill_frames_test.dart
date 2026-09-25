// tool/boss_kill_frames_test.dart — review strips for the run-ending boss
// kill (experimental loop C1-01 evidence + C2-02 victory beat). NOT part of
// `flutter test` (lives in tool/). Lands a run-ending blow on each of two
// final bosses (FIXTURE: the seed-1 fight's node and foe are re-dressed as
// the boss, HP set so the die kills — the sim's rules are untouched) with
// the shipped fonts and every PNG precached, and writes:
//   build/boss_kill/<boss>_<normal|reduced>_360x800/t0040.png … t1600.png
//       every 40 ms after ATTACK, normal and reduced motion;
//   build/boss_kill/victory_<size>_t0600.png / _t1200.png
//       the victory plates at 320x568, 360x800 and 412x915.
// It prints, per strip, the share of frames with > 50% of pixels at
// luma > 230 (the old white-out) so the numbers go into the pack.
//   flutter test tool/boss_kill_frames_test.dart
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

const _bosses = {
  'ember_tyrant': 'Ember Tyrant',
  'ashen_colossus': 'Ashen Colossus',
};

/// Writes [path] and returns the share of pixels at luma > 230.
Future<double> png(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    final raw = Uint8List.sublistView((await image.toByteData())!);
    var bright = 0;
    for (var i = 0; i < raw.length; i += 4) {
      final y = 0.299 * raw[i] + 0.587 * raw[i + 1] + 0.114 * raw[i + 2];
      if (y > 230) bright++;
    }
    final share = bright / (image.width * image.height);
    image.dispose();
    return share;
  }))!;
}

Future<void> run(
  WidgetTester tester, {
  required String boss,
  required Size size,
  required bool reduced,
  required bool strip,
}) async {
  tester.view.physicalSize = size * 2;
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
    for (final a in manifest.listAssets().where((a) => a.endsWith('.png'))) {
      await precacheImage(AssetImage(a), context);
    }
  });
  await k.toFight(tester, c);
  // FIXTURE: re-dress the seed-1 foe as the final boss before the roll.
  final map = c.sim!.map!;
  ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
  c.sim!.enemy!['id'] = boss;
  c.sim!.enemy!['name'] = _bosses[boss];
  c.sim!.enemy!['boss'] = true;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
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
  c.sim!.enemy!['hp'] = value - 1;
  c.sim!.enemy!['block'] = 0;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  final tag = '${size.width.toInt()}x${size.height.toInt()}';
  if (strip) {
    await png(
      tester,
      key,
      'build/boss_kill/${boss}_${reduced ? 'reduced' : 'normal'}_$tag/t0000.png',
    );
  }
  await tester.tap(
    find.byWidgetPredicate((w) => w is DieChip && w.value != null).at(die - 1),
  );
  await tester.pump();
  await tester.tap(k.button('Attack'));
  var frames = 0, whiteOut = 0;
  var peak = 0.0;
  for (var ms = 40; ms <= 1600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    final t = ms.toString().padLeft(4, '0');
    if (strip) {
      final share = await png(
        tester,
        key,
        'build/boss_kill/${boss}_${reduced ? 'reduced' : 'normal'}_$tag/t$t.png',
      );
      frames++;
      if (share > 0.5) whiteOut++;
      if (share > peak) peak = share;
    } else if (ms == 600 || ms == 1200) {
      await png(tester, key, 'build/boss_kill/victory_${tag}_t$t.png');
    }
  }
  if (strip) {
    // ignore: avoid_print
    print(
      'STRIP $boss ${reduced ? 'reduced' : 'normal'} $tag: $frames frames, '
      '$whiteOut with >50% pixels at luma>230, peak '
      '${(peak * 100).toStringAsFixed(1)}%, phase ${c.phase}',
    );
  }
  await tester.pumpWidget(const SizedBox.shrink());
  for (var t = 0; t < 3000; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
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
  for (final boss in _bosses.keys) {
    for (final reduced in [false, true]) {
      testWidgets('boss kill strip $boss ${reduced ? 'reduced' : 'normal'}', (
        t,
      ) async {
        await run(
          t,
          boss: boss,
          size: const Size(360, 800),
          reduced: reduced,
          strip: true,
        );
      });
    }
  }
  for (final size in const [Size(320, 568), Size(360, 800), Size(412, 915)]) {
    testWidgets('victory plates ${size.width.toInt()}', (t) async {
      await run(
        t,
        boss: 'ember_tyrant',
        size: size,
        reduced: false,
        strip: false,
      );
    });
  }
}
