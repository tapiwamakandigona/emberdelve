// tool/delve_code_visual_test.dart — manual visual-critique plates for the
// v0.37.0 Delve Codes. Not part of CI.
//
//   flutter test tool/delve_code_visual_test.dart
//
// Plates (build/delve_code_visual/):
//   • card_code — the Delver's Card carrying the code line (longer than the
//     old seed line: does it still sit cleanly at 340 wide?).
//   • summary_code_row — a real finished run's summary with the tap-to-copy
//     Delve Code row in frame.
//   • dialog_code — the 'Delve a seed' dialog with its updated copy.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/delve_code_visual';

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

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> snap(
  WidgetTester tester,
  GlobalKey key,
  String name,
  double ratio,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: ratio),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
    switch (c.phase) {
      case 'boon':
        c.apply({'type': 'choose_boon', 'index': 0});
        break;
      case 'map':
        final m = c.state!['map'] as Map;
        final e = (m['edges'] as Map).cast<String, List>();
        final p = m['position'] as int;
        c.apply({
          'type': 'choose_node',
          'node': (e['$p'] as List).cast<int>().first,
        });
        break;
      case 'player_turn':
        c.apply({'type': 'roll'});
        c.apply({'type': 'end_turn'});
        break;
      case 'reward':
        c.apply({'type': 'choose_reward', 'index': 0});
        break;
      case 'rest':
        c.apply({'type': 'rest'});
        break;
      case 'shop':
        c.apply({'type': 'leave_shop'});
        break;
      case 'event':
        c.apply({'type': 'event_choose', 'option': 1});
        break;
    }
  }
}

void main() {
  testWidgets('delve code plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    // 1. The card with a full code line at the widest realistic facts.
    final code = encodeDelveCode(
      seed: 2147480000,
      character: 'ascetic',
      difficulty: 'hard',
      ascension: 99,
    )!;
    final facts = DelverCardFacts(
      won: true,
      delverName: 'The Ascetic',
      epithetTitle: 'the Highborne',
      difficulty: 'hard',
      ascension: 99,
      traceGridText: '',
      embers: 1840,
      fightsWon: 14,
      seed: 2147480000,
      delveCode: code,
    );
    tester.view.physicalSize = const Size(360, 440) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final cardKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: Material(
          color: const Color(0xFF222222),
          child: Center(
            child: RepaintBoundary(key: cardKey, child: DelverCard(facts)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, cardKey, 'card_code', 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // 2. A real summary with the code row (seed 13 easy loss, kindler).
    const logical = Size(360, 640);
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    final sumKey = GlobalKey();
    final c = GameController();
    await tester.pumpWidget(
      RepaintBoundary(
        key: sumKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: logical),
            child: GameRoot(c),
          ),
        ),
      ),
    );
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    c.startRun(character: 'kindler', seed: 13, difficulty: 'easy');
    await pumpFor(tester, 700);
    driveToTerminal(c);
    await pumpFor(tester, 2500);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('run-seed')),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await pumpFor(tester, 400);
    await snap(tester, sumKey, 'summary_code_row', 2);

    // 3. The seed dialog with its updated copy.
    final c2 = GameController();
    final dlgKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: dlgKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: logical),
            child: GameRoot(c2),
          ),
        ),
      ),
    );
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await pumpFor(tester, 400);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('seeded-delve')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('seeded-delve')));
    await pumpFor(tester, 400);
    await snap(tester, dlgKey, 'dialog_code', 2);

    debugPrint('STAGE: delve code plates done');
  });
}
