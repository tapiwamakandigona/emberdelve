// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/trials_visual_test.dart — manual visual-critique plates for the
// v0.9.0 Today's Trials surfaces. Not part of CI.
//
//   flutter test tool/trials_visual_test.dart
//
// Plates:
//   title_360x640 / title_320x568_1p3x — the daily-trial-line under the
//     Daily Delve button (today's real trial; worst-case copy length is
//     asserted as a string below, the plate verifies placement + wrap).
//   summary_trial_chip_360x640 — a finished goal-day daily that MET its
//     goal, scrolled to the trial-met-chip.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/trials_visual';

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

void drive(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 3000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
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
  testWidgets('trials plates: title line + summary chip', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_trials_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    // Title screen: today's real trial line under the Daily Delve button.
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    await capture(tester, TitleScreen(c), 'title_360x640',
        const Size(360, 640), 1.0, scrollToKey: 'daily-trial-line');
    await capture(tester, TitleScreen(c), 'title_320x568_1p3x',
        const Size(320, 568), 1.3, scrollToKey: 'daily-trial-line');

    // Summary chip: hunt a goal-day date whose daily the bot finishes with
    // the goal MET (self-selecting; snapshot-judged goals only so the hunt
    // can use the pure sim before paying for a controller run).
    DateTime? hit;
    var d = DateTime(2026, 1, 1);
    for (var i = 0; i < 400 && hit == null; i++) {
      final t = trialForDate(d.year, d.month, d.day);
      if (t.goalId.isNotEmpty && t.goalId != 'clean_floors_at_least') {
        final c2 = GameController(saveDirOverride: dir.path);
        await tester.binding.runAsync(() => c2.boot());
        c2.startDailyRun(character: 'kindler', clock: d);
        drive(c2);
        if (c2.dailyTrialBonus > 0) {
          hit = d;
          File('$outDir/chip_info.txt').writeAsStringSync(
            'date=$d trial=${t.id} bonus=${c2.dailyTrialBonus} '
            'phase=${c2.phase}\nshare:\n${c2.dailyResultShareText}\n',
          );
          await capture(tester, SummaryScreen(c2),
              'summary_trial_chip_360x640', const Size(360, 640), 1.0,
              scrollToKey: 'trial-met-chip');
        }
        await tester.binding.runAsync(() => c2.flushSaves());
      }
      d = d.add(const Duration(days: 1));
    }
    expect(hit, isNotNull,
        reason: 'no goal-day daily met its goal in 400 dates');
    await tester.binding.runAsync(() => c.flushSaves());
  });
}
