// tool/fresh_walk_visual_test.dart — plates of a BRAND-NEW profile's first
// minutes at 360×800 with the shipped fonts: title, boon, map, first fight
// (tour beat), the run's end (summary). Critique pass for everything the
// v0.180.0 draft touched on that path. Not CI.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

final outDir =
    'build/fresh_walk_visual_${Platform.environment["PLATE_W"] ?? "360"}';

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
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

Future<bool> tapButton(WidgetTester tester, String label) async {
  final f = find.widgetWithText(EmberButton, label);
  if (f.evaluate().isEmpty) return false;
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 100));
  } catch (_) {}
  await tester.tap(f.first, warnIfMissed: false);
  return true;
}

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
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
  // ignore: avoid_print
  print(
    'PLATE $name phase=${find.byType(GameRoot).evaluate().isEmpty ? '?' : ''}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh profile walk', (tester) async {
    await loadRealFonts();
    final w = double.parse(Platform.environment["PLATE_W"] ?? "360");
    final h = double.parse(Platform.environment["PLATE_H"] ?? "800");
    tester.view.physicalSize = Size(w, h) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final dir = Directory('build/fresh_walk_visual/save');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: RepaintBoundary(key: key, child: GameRoot(c)),
      ),
    );
    await pumpFor(tester, 1500);
    await snap(tester, key, '01_title_fresh');

    c.debugNextRunSeed = 1;
    expect(await tapButton(tester, 'Delve'), isTrue);
    await pumpFor(tester, 1200);
    // ignore: avoid_print
    print('after Delve: ${c.phase}');
    await snap(tester, key, '02_after_delve_${c.phase}');

    // Boon pick — tap the first live card.
    final cards = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTap != null,
    );
    final n = cards.evaluate().length;
    for (var i = 0; i < n && c.phase == 'boon'; i++) {
      await tester.tap(cards.at(i), warnIfMissed: false);
      await pumpFor(tester, 400);
    }
    await pumpFor(tester, 1200);
    // ignore: avoid_print
    print('after boon: ${c.phase}');
    await snap(tester, key, '03_map_fresh');

    final m = c.state!['map'] as Map;
    final pos = m['position'] as int;
    final reach = ((m['edges'] as Map)['$pos'] as List).cast<int>();
    final nodeKey = find.byKey(ValueKey('map-node-${reach.first}'));
    for (var i = 0; i < 8 && c.phase == 'map'; i++) {
      try {
        await tester.ensureVisible(nodeKey.first);
      } catch (_) {}
      await tester.tap(nodeKey.first, warnIfMissed: false);
      await pumpFor(tester, 900);
    }
    await pumpFor(tester, 1500);
    // ignore: avoid_print
    print(
      'after node: ${c.phase} tour=${c.tour.running} beat=${c.tour.active}',
    );
    await snap(tester, key, '04_first_fight_tour');

    // Walk the tour the way a player would: ROLL, then a stray END TURN
    // (must be held), then a die, then ATTACK, then the two info taps.
    await tester.tap(find.text('Roll'), warnIfMissed: false);
    await pumpFor(tester, 900);
    await snap(tester, key, '05_tour_beat_pick');
    final turnBefore = c.state!['turn'];
    await tester.tap(find.text('End turn'), warnIfMissed: false);
    await pumpFor(tester, 900);
    // ignore: avoid_print
    print('stray END TURN under pick: turn $turnBefore → ${c.state!['turn']}');
    final dieKeys = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTap != null,
    );
    for (
      var i = 0;
      i < dieKeys.evaluate().length && c.tour.active == 'tour_pick';
      i++
    ) {
      await tester.tap(dieKeys.at(i), warnIfMissed: false);
      await pumpFor(tester, 300);
    }
    await snap(tester, key, '05_tour_beat_spend_${c.tour.active}');
    await tester.tap(find.text('Attack'), warnIfMissed: false);
    await pumpFor(tester, 1200);
    await snap(tester, key, '05_tour_beat_intent_${c.tour.active}');
    for (var b = 0; b < 3 && c.tour.running; b++) {
      await tester.tapAt(const Offset(180, 400));
      await pumpFor(tester, 700);
    }
    // ignore: avoid_print
    print(
      'tour done: running=${c.tour.running} stamp=${c.meta.tourSeenVersion}',
    );

    // Drive the run to its end with the bot, then plate the summary.
    var guard = 0;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    await pumpFor(tester, 2500);
    // ignore: avoid_print
    print('end: ${c.phase} runsPlayed=${c.meta.runsPlayed}');
    await snap(tester, key, '06_summary_${c.phase}');
    await pumpFor(tester, 1500);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
