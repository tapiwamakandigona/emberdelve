// Visual review harness for the 2026-09-24 "living foes" pass (Ashfall
// deaths, charging foes). NOT a correctness test and NOT part of
// `flutter test` (it lives in tool/): it renders the real GameRoot /
// CombatScreen with the shipped fonts, sprites and painters at phone size,
// drives a real fight through hit-tested production controls and writes PNG
// frames for human review. Run:
//   flutter test tool/living_foes_frames_test.dart
// Frames land in build/living_foes_frames/<case>/. FOES=<id,id> swaps the
// foe's sprite id (fixture only) to review other bodies with the same fight.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
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

const outDir = 'build/living_foes_frames';
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
  final foes =
      Platform.environment['FOES']?.split(',') ??
      ['flue_crawler', 'cinder_wisp', 'slag_brute', 'molten_maw'];
  for (final foe in foes) {
    testWidgets('living foes frames: $foe', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'off');
      final dir = Directory('$outDir/$foe')..createSync(recursive: true);
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
        character: 'kindler',
        boons: true,
        seed: 1,
        difficulty: 'easy',
      );
      c.apply({'type': 'choose_boon', 'index': 0});
      c.apply({'type': 'choose_node', 'node': 2});
      await pumpMs(tester, 2600);
      expect(c.phase, 'player_turn');
      // FIXTURE ONLY (review harness): swap the body on screen.
      c.sim!.enemy!['id'] = foe;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpMs(tester, 400);
      var n = 0;
      Future<void> frames(
        int count,
        String label, {
        Duration every = step,
      }) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(every);
          await png(
            tester,
            key,
            '${dir.path}/${n.toString().padLeft(3, '0')}-$label.png',
          );
          n++;
        }
      }

      // Enemy turn first (charging foe), then a lethal blow (Ashfall).
      await tester.tap(button('Roll'));
      await pumpMs(tester, 2000);
      await frames(20, 'idle', every: const Duration(milliseconds: 100));
      await tester.tap(button('End turn'));
      await frames(24, 'enemy-turn');
      await pumpMs(tester, 2400);
      await tester.tap(button('Roll'));
      await pumpMs(tester, 2000);
      final rolled = (c.sim!.player['rolled'] as List).length;
      var die = 1;
      for (var d = 1; d <= rolled; d++) {
        final r = resolveAssignment(
          player: c.sim!.player,
          enemy: c.sim!.enemy!,
          run: c.sim!.run,
          die: d,
          action: 'attack',
        );
        if (r.allowed && r.value > 0) {
          die = d;
          break;
        }
      }
      c.sim!.enemy!['hp'] = 1;
      c.sim!.enemy!['block'] = 0;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await tester.pump();
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      await tester.tap(dice.at(die - 1));
      await tester.pump();
      await tester.tap(button('Attack'));
      await frames(34, 'kill');
      await pumpMs(tester, 3000);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpMs(tester, 2000);
    });
  }
}
