// Review evidence only, NOT a replacement/weakening of any existing test.
// Actual release-identical UI and assets; setup is a deterministic fixture.
// Taps after setup are hit-tested through production die/action controls.
// Captured 25fps simulated-time frames are NOT native Android frame timings.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/combat_review_frames';
const step = Duration(milliseconds: 40);
final records = <Map<String, Object?>>[];

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
  for (final character in ['kindler', 'warden', 'gambler', 'runesmith']) {
    testWidgets('actual combat review frames: $character', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'off');
      final directory = Directory('$outDir/$character')
        ..createSync(recursive: true);
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
      // Public start-run/boon/map commands only; no forced rolls or sim edits.
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
      expect(c.sim!.enemy!['id'], 'flue_crawler');
      expect(button('Roll'), findsOneWidget);
      await tester.tap(button('Roll'));
      await pumpMs(tester, 2600);
      final rolled = (c.sim!.player['rolled'] as List).cast<int>();
      expect(rolled[0], 5);
      expect(rolled[1], 1);
      await png(tester, key, '${directory.path}/rolled.png');
      var number = 0;
      final labels = <String>[];
      Future<void> frames(int count, String label) async {
        for (var n = 0; n < count; n++) {
          await tester.pump(step);
          final filename =
              '${directory.path}/frame-${number.toString().padLeft(4, '0')}.png';
          await png(tester, key, filename);
          labels.add(label);
          number++;
        }
      }

      await frames(10, 'idle');
      for (final pair in [(1, 1), (0, 5)]) {
        final dieIndex = pair.$1;
        final value = pair.$2;
        final dice = find.byWidgetPredicate(
          (widget) => widget is DieChip && widget.value != null,
        );
        expect(dice, findsNWidgets(rolled.length));
        final chip = dice.at(dieIndex);
        await tester.tap(chip);
        await frames(10, 'selected-$value');
        final weaponBefore = tester.widget<WeaponView>(find.byType(WeaponView));
        final hpBefore = c.sim!.enemy!['hp'];
        records.add({
          'character': character,
          'phase': 'selected',
          'face': value,
          'weapon_charge': weaponBefore.charge,
          'frame': number,
          'rolled': rolled,
          'enemy_hp': hpBefore,
        });
        await png(tester, key, '${directory.path}/selected-$value.png');
        expect(button('Attack'), findsOneWidget);
        await tester.tap(button('Attack'));
        await tester.pump();
        final weaponDuring = tester.widget<WeaponView>(find.byType(WeaponView));
        records.add({
          'character': character,
          'phase': 'attack',
          'face': value,
          'weapon_charge': weaponDuring.charge,
          'frame': number,
          'enemy_hp_before': hpBefore,
          'enemy_hp_after': c.sim!.enemy!['hp'],
        });
        await frames(35, 'attack-$value');
        await png(tester, key, '${directory.path}/resolved-$value.png');
      }
      await tester.tap(button('End turn'));
      await frames(40, 'enemy-turn');
      expect(tester.takeException(), isNull);
      File('${directory.path}/timeline.json').writeAsStringSync(
        jsonEncode({
          'fps': 25,
          'frames': labels,
          'method':
              'Real Flutter widgets; simulated-time headless rendering, not Android video',
          'seed': 1,
          'character': character,
          'roll': rolled,
        }),
      );
      File('$outDir/observations.json').writeAsStringSync(jsonEncode(records));
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpMs(tester, 2200);
      c.dispose();
    });
  }
}
