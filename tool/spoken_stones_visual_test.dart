// tool/spoken_stones_visual_test.dart — plates of the three v0.180.0 events on
// the event screen at 320×568 and 360×800 with the shipped fonts. Not CI.
// Prints AUDIT lines (scroll extent must be 0 — decision screens fit).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/spoken_stones_visual';
const ids = ['the_fair_scale', 'the_two_marks', 'the_first_lantern', 'rivals_ledger', 'the_old_rope', 'tyrants_echo'];

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
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String extent(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byType(Scrollable).evaluate()) {
    final st = (e as StatefulElement).state as ScrollableState;
    if (st.position.hasContentDimensions && st.position.axis == Axis.vertical) {
      out.add(st.position.maxScrollExtent.toStringAsFixed(0));
    }
  }
  return out.isEmpty ? '0' : out.join('/');
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(320, 568), Size(360, 800)]) {
    for (final id in ids) {
      testWidgets('$id $size', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final c = GameController();
        c.meta
          ..tourSeenVersion = tourVersion
          ..tutorialSeen = true
          ..tipsSeen.addAll(ContextTips.all)
          ..lastSeenNewsVersion = currentAppVersion;
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildEmberTheme(),
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: RepaintBoundary(key: key, child: GameRoot(c)),
            ),
          ),
        );
        await pumpFor(tester, 300);
        c.startRun(character: 'kindler', seed: 5, boons: false);
        await pumpFor(tester, 300);
        final map = c.state!['map'] as Map;
        final position = map['position'] as int;
        final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        final ev = edges.firstWhere((e) => nodes['$e']!['kind'] == 'event');
        c.apply({'type': 'choose_node', 'node': ev});
        expect(c.phase, 'event');
        c.sim!.event = id;
        // ignore: invalid_use_of_protected_member
        c.notifyListeners();
        await pumpFor(tester, 900);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.binding.runAsync(
          () => boundary.toImage(pixelRatio: 2),
        );
        final bytes = await tester.binding.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        File('$outDir/${id}_${size.width.toInt()}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
        // ignore: avoid_print
        print('AUDIT $id ${size.width.toInt()} scroll=${extent(tester)}');
        await pumpFor(tester, 1200);
      });
    }
  }
}
