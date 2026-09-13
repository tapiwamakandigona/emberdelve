// Visual review harness for v0.183.0 "Bodies in the Fight". NOT a test of
// correctness and NOT a replacement for any existing test: it renders the
// real GameRoot/CombatScreen with the shipped fonts, sprites and painters at
// phone size, drives it through hit-tested production controls, and writes
// PNG frames so a human can judge grip, strike families, guard, blood and
// low-health body language. Run:
//   flutter test tool/combat_bodies_frames_test.dart
// Frames land in build/combat_bodies_frames/<character>/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/combat_bodies_frames';
const step = Duration(milliseconds: 40);

Future<void> fonts() async {
  for (final entry in {
    'Cinzel': 'assets/fonts/Cinzel-Variable.ttf',
    'Inter': 'assets/fonts/Inter-Regular.ttf',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    final data = ByteData.sublistView(File(entry.value).readAsBytesSync());
    await (FontLoader(entry.key)..addFont(Future.value(data))).load();
  }
}

Finder button(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is EmberButton && widget.label == label && widget.onTap != null,
);

Future<void> pumpMs(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 40) {
    await tester.pump(step);
  }
}

Future<void> png(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(fonts);
  final chars =
      Platform.environment['BODIES_CHARS']?.split(',') ??
      ['kindler', 'warden', 'gambler', 'runesmith'];
  for (final character in chars) {
    testWidgets('bodies frames: $character', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'off');
      final dir = Directory('$outDir/$character')..createSync(recursive: true);
      final c = GameController();
      c.meta.tutorialSeen = true;
      c.meta.tipsSeen.addAll(ContextTips.all);
      c.tipDirector = TipDirector(c.meta.tipsSeen);
      c.meta.tourSeenVersion = tourVersion;
      c.tour = TourDirector(seenVersion: tourVersion);
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
        for (final asset in manifest.listAssets().where(
          (a) => a.endsWith('.png'),
        )) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      c.startRun(
        character: character,
        boons: true,
        seed: 1,
        difficulty: 'easy',
      );
      c.apply({'type': 'choose_boon', 'index': 0});
      c.apply({'type': 'choose_node', 'node': 2});
      await pumpMs(tester, 2600);
      expect(c.phase, 'player_turn');
      // FIXTURE ONLY (review harness): put the delver at a third health so
      // the low-health body language is visible in the same capture.
      c.sim!.player['hp'] = ((c.sim!.player['max_hp'] as int) * 0.3).round();
      c.sim!.enemy!['hp'] = ((c.sim!.enemy!['max_hp'] as int) * 0.5).round();
      c.notifyListeners();
      await tester.tap(button('Roll'));
      await pumpMs(tester, 2600);
      final rolled = (c.sim!.player['rolled'] as List).cast<int>();
      var n = 0;
      Future<void> frames(int count, String label) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(step);
          await png(
            tester,
            key,
            '${dir.path}/${n.toString().padLeft(3, '0')}-$label.png',
          );
          n++;
        }
      }

      await frames(2, 'idle');
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      // Low face first: block with it (guard stance), then the high face attacks.
      final lowIdx = rolled.indexOf(rolled.reduce((a, b) => a < b ? a : b));
      final highIdx = rolled.indexOf(rolled.reduce((a, b) => a > b ? a : b));
      await tester.tap(dice.at(lowIdx));
      await frames(3, 'selected-low');
      await tester.tap(button('Block'));
      await frames(8, 'guard');
      await tester.tap(dice.at(highIdx));
      await frames(3, 'selected-high');
      await tester.tap(button('Attack'));
      await frames(22, 'attack');
      await tester.tap(button('End turn'));
      await frames(30, 'enemy-turn');
      await pumpMs(tester, 3000);
      await frames(2, 'after');
    });
  }
}
