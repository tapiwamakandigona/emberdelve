// tool/midrun_scroll_visual_test.dart — scroll-extent audit + plates for the
// mid-run screens (map, shop, rest, event, reward, keystone) at 360×800 with
// the shipped fonts. Not part of CI. Prints AUDIT lines.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/midrun_scroll_visual';
Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async => ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load(); await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) { final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))); await icons.load(); }
  }
}
Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) { await tester.pump(const Duration(milliseconds: 50)); }
}
Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.binding.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$outDir/$name.png')..createSync(recursive: true)..writeAsBytesSync(bytes!.buffer.asUint8List());
}
String extent(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byType(Scrollable).evaluate()) {
    final st = (e as StatefulElement).state as ScrollableState;
    if (st.position.hasContentDimensions && st.position.axis == Axis.vertical) {
      out.add('${st.position.maxScrollExtent.toStringAsFixed(0)}/${st.position.viewportDimension.toStringAsFixed(0)}');
    }
  }
  return out.isEmpty ? 'none' : out.join(' ');
}
void main() {
  setUpAll(loadRealFonts);
  for (final (size, seed) in const [(Size(360, 800), 11), (Size(412, 915), 11), (Size(360, 800), 5), (Size(412, 915), 5)]) {
  testWidgets('midrun $size seed $seed', (tester) async {
    tester.view.physicalSize = size * 2; tester.view.devicePixelRatio = 2; addTearDown(tester.view.reset);
    final c = GameController();
    c.meta..tourSeenVersion = tourVersion..tutorialSeen = true..tipsSeen.addAll(ContextTips.all)..lastSeenNewsVersion = currentAppVersion..runsPlayed = 3..difficultyChosen = true;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildEmberTheme(), home: MediaQuery(data: MediaQueryData(size: size), child: GameRoot(c)))));
    await tester.binding.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await pumpFor(tester, 400);
    c.startRun(character: 'kindler', seed: seed, boons: true);
    await pumpFor(tester, 600);
    c.apply({'type': 'choose_boon', 'index': 1});
    // Fat pool so the rest forge list is long.
    (c.state!['player'] as Map)['dice'] = <String>[for (final d in diceOrder.take(10)) d];
    (c.state!['player'] as Map)['gold'] = 200;
    final seen = <String>{}; final r = <String>[]; var guard = 0;
    final tag = '${size.width.toInt()}_s$seed';
    while (guard++ < 3000 && c.phase != null && c.phase != 'run_won' && c.phase != 'run_lost') {
      final phase = c.phase!;
      if (!seen.contains(phase) && phase != 'player_turn' && phase != 'enemy_turn') {
        seen.add(phase);
        await pumpFor(tester, 700);
        r.add('$phase=${extent(tester)}');
        await snap(tester, key, '${phase}_$tag');
      }
      if (phase == 'map') {
        final map = c.state!['map'] as Map;
        final position = map['position'] as int;
        final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        int pick = edges.first;
        for (final e in edges) {
          final kind = nodes['$e']!['kind'] as String;
          if (!seen.contains(kind) && (kind == 'shop' || kind == 'event' || kind == 'rest')) { pick = e; break; }
        }
        c.apply({'type': 'choose_node', 'node': pick});
        (c.state!['player'] as Map)['hp'] = 30;
        continue;
      }
      final cmd = botCmd(c.sim!); if (cmd == null) break; c.apply(cmd);
    }
    // ignore: avoid_print
    print('AUDIT $size ${r.join(' | ')}');
    await pumpFor(tester, 1500);
  });
  }
}
