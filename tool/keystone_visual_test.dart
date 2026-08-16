// tool/keystone_visual_test.dart — manual visual-critique plate for the v7
// keystone chooser, captured from the real screen inside a real run. Not part
// of CI.
//
//   flutter test tool/keystone_visual_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/keystone_visual';

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  for (final probe in <List<Object>>[
    ['phone', const Size(412, 915), 1.0],
    ['small', const Size(360, 640), 1.0],
    ['large-text', const Size(412, 915), 1.6],
  ]) {
    final label = probe[0] as String;
    final size = probe[1] as Size;
    final scale = probe[2] as double;

    testWidgets('keystone chooser @ $label', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final c = GameController();
      c.meta.tutorialSeen = true;
      c.meta.tipsSeen.addAll(ContextTips.all);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          // copyWith, never a bare MediaQueryData: a fresh one has size
          // zero, which silently collapses any widget that measures the
          // screen (it hid the temper sheet's controls entirely).
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: GameRoot(c),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Play into the first won fight, which is where the offering lands.
      c.startRun(character: 'kindler', seed: 2);
      await tester.pump(const Duration(milliseconds: 400));
      var guard = 0;
      while (c.phase != 'keystone' && guard++ < 80) {
        final phase = c.phase;
        if (phase == 'boon') {
          c.apply({'type': 'choose_boon', 'index': 1});
        } else if (phase == 'map') {
          final map = c.state!['map'] as Map;
          final pos = map['position'] as int;
          final edges = ((map['edges'] as Map)['$pos'] as List).cast<int>();
          c.apply({'type': 'choose_node', 'node': edges.first});
        } else if (phase == 'player_turn') {
          c.apply({'type': 'roll'});
          final n = ((c.state!['player'] as Map)['dice'] as List).length;
          for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
            c.apply({
              'type': 'assign',
              'die': i,
              'action': i.isEven ? 'block' : 'attack',
            });
          }
          if (c.phase == 'player_turn') c.apply({'type': 'end_turn'});
        } else if (phase == 'rest') {
          c.apply({'type': 'rest'});
        } else if (phase == 'shop') {
          c.apply({'type': 'leave_shop'});
        } else if (phase == 'event') {
          c.apply({'type': 'event_choose', 'option': 1});
        } else {
          break;
        }
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
      }
      expect(c.phase, 'keystone', reason: 'never reached the offering');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await _shoot(tester, key, 'keystone-$label');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
