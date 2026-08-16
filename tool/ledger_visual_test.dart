// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/ledger_visual_test.dart — manual visual-critique plates for the
// v0.11.0 Delver's Ledger surfaces. Not part of CI.
//
//   flutter test tool/ledger_visual_test.dart
//
// Plates:
//   codex_record_360x640 — an enemy with a full record line
//     (Met 3 · Felled 2 · Deaths 1) plus a never-met neighbour, so both
//     copy shapes are judged in one frame.
//   codex_record_320x568_1p3x — same, worst-case small screen at 1.3x.
//   summary_firsts_360x640 — a real fresh-profile bot run (seed 503,
//     boons) ending on the summary, scrolled to the firsts line.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/ledger_visual';

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

Future<void> capture(
  WidgetTester tester,
  Widget screen,
  String name,
  Size logical,
  double textScale, {
  String? scrollToKey,
}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: logical,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (scrollToKey != null) {
    await tester.ensureVisible(find.byKey(ValueKey(scrollToKey)));
    await tester.pump(const Duration(milliseconds: 400));
  }
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
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('ledger plates: codex record + summary firsts', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_ledger_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    // Codex: one enemy with the full three-part record, neighbours unmet.
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    c.meta.enemyMet['cinder_wisp'] = 3;
    c.meta.enemyFelled['cinder_wisp'] = 2;
    c.meta.enemyFellTo['cinder_wisp'] = 1;
    await capture(tester, CodexScreen(c), 'codex_record_360x640',
        const Size(360, 640), 1.0, scrollToKey: 'codex-record-cinder_wisp');
    await capture(tester, CodexScreen(c), 'codex_record_320x568_1p3x',
        const Size(320, 568), 1.3, scrollToKey: 'codex-record-cinder_wisp');
    debugPrint('STAGE: codex plates done');

    // Summary firsts line after a real fresh-profile run.
    final dir2 = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_ledger_visual2'),
    );
    MetaStore.dirOverride = dir2!.path;
    final c2 = GameController(saveDirOverride: dir2.path);
    await tester.binding.runAsync(() => c2.boot());
    debugPrint('STAGE: c2 booted');
    // Drive the whole run inside runAsync: with a real saveDirOverride each
    // apply() initiates real file I/O, and I/O born in the FakeAsync zone
    // never completes — flushSaves would hang forever otherwise.
    await tester.binding.runAsync(() async {
      c2.startRun(character: 'kindler', seed: 503, boons: true);
      var guard = 0;
      while (guard++ < 3000 &&
          c2.phase != 'run_won' &&
          c2.phase != 'run_lost') {
        final cmd = botCmd(c2.sim!);
        if (cmd == null) break;
        c2.apply(cmd);
      }
      await c2.flushSaves();
      // NOTE deliberately no c.flushSaves(): c never queued a save, so its
      // _saveQueue is still the constructor's Future.value() — a future BORN
      // in the FakeAsync zone. Awaiting an already-completed future resolves
      // through its creation zone's microtask queue, so awaiting that one
      // here (even inside runAsync) deadlocks forever.
    });
    expect({'run_won', 'run_lost'}.contains(c2.phase), isTrue);
    debugPrint('STAGE: capturing summary');
    await capture(tester, SummaryScreen(c2), 'summary_firsts_360x640',
        const Size(360, 640), 1.0, scrollToKey: 'firsts-line');
    debugPrint('STAGE: summary plate done');
  });
}
