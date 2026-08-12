// tool/temper_visual_test.dart — manual visual-critique plates for the v7
// Face Forge: the temper sheet at three sizes, and a tempered die in the
// combat tray wearing its rune mark. Not part of CI.
//
//   flutter test tool/temper_visual_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/temper_visual';

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

Future<void> _pump(WidgetTester tester, [int ticks = 6]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  for (final probe in <List<Object>>[
    ['phone', const Size(412, 915), 1.0],
    ['small', const Size(360, 640), 1.0],
    ['large-text', const Size(412, 915), 1.5],
  ]) {
    final label = probe[0] as String;
    final size = probe[1] as Size;
    final scale = probe[2] as double;

    testWidgets('temper sheet @ $label', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final c = GameController();
      c.meta.tutorialSeen = true;
      c.startRun(character: 'kindler', seed: 5, boons: false);
      c.sim!.phase = 'rest';
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
      await _pump(tester);
      await _shoot(tester, key, 'rest-$label');

      await tester.tap(find.byKey(const ValueKey('rest-temper')));
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('temper-die-1')));
      await _pump(tester, 3);
      await tester.tap(find.byKey(const ValueKey('temper-face-4')));
      await _pump(tester, 3);
      await tester.tap(find.byKey(const ValueKey('temper-rune-surge')));
      await _pump(tester, 3);
      await _shoot(tester, key, 'sheet-$label');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('tempered die in the combat tray', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta.tutorialSeen = true;
    c.startRun(character: 'kindler', seed: 5, boons: false);
    c.sim!.phase = 'rest';
    c.apply({'type': 'temper_face', 'die': 1, 'face': 4, 'rune': 'blade'});

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
    await _pump(tester);

    var guard = 0;
    while (c.phase != 'player_turn' && guard++ < 30) {
      final phase = c.phase;
      if (phase == 'map') {
        final map = c.state!['map'] as Map;
        final pos = map['position'] as int;
        final edges = ((map['edges'] as Map)['$pos'] as List).cast<int>();
        c.apply({'type': 'choose_node', 'node': edges.first});
      } else if (phase == 'rest') {
        c.apply({'type': 'rest'});
      } else if (phase == 'shop') {
        c.apply({'type': 'leave_shop'});
      } else if (phase == 'event') {
        c.apply({'type': 'event_choose', 'option': 1});
      } else {
        break;
      }
      await _pump(tester, 4);
    }
    expect(c.phase, 'player_turn');
    c.apply({'type': 'roll'});
    await _pump(tester, 12);
    await _shoot(tester, key, 'tray-tempered');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
