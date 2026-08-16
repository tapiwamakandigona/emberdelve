// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/tablet_visual_test.dart — manual visual-critique plates for the
// v0.26.0 tablet-portrait quality pass. Not part of CI.
//
//   flutter test tool/tablet_visual_test.dart
//
// Captures menu-family + in-run column screens at tablet-portrait logical
// sizes (800x1280 = 10" tablet, 600x960 = 7" tablet) so the before/after of
// the width clamp can be judged by eye. Combat and map are deliberately NOT
// plated: they scale and are out of scope for the clamp.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/data/skins.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/tablet_visual';

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
) async {
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
          data: MediaQueryData(size: logical),
          child: Scaffold(body: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 1.5),
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

/// Drives the controller into [wantPhase] by walking the map like the
/// overflow probe does. Returns true when reached.
bool driveToPhase(GameController c, String wantPhase, {int seed = 7}) {
  c.startRun(character: 'kindler', seed: seed, boons: true);
  if (wantPhase == 'boon') return c.phase == 'boon';
  c.apply({'type': 'choose_boon', 'index': 1});
  var guard = 0;
  while (guard++ < 40 && c.phase != null && c.phase != 'run_lost') {
    if (c.phase == wantPhase) return true;
    final phase = c.phase;
    if (phase == 'map') {
      final map = c.state!['map'] as Map;
      final position = map['position'] as int;
      final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
      final nodes = (map['nodes'] as Map).cast<String, Map>();
      int pick = edges.first;
      for (final e in edges) {
        if (nodes['$e']!['kind'] == wantPhase ||
            (wantPhase == 'player_turn' &&
                (nodes['$e']!['kind'] == 'fight'))) {
          pick = e;
          break;
        }
      }
      c.apply({'type': 'choose_node', 'node': pick});
    } else if (phase == 'player_turn') {
      c.apply({'type': 'roll'});
      final player = c.state!['player'] as Map;
      final n = (player['dice'] as List).length;
      for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
        c.apply({
          'type': 'assign',
          'die': i,
          'action': i.isEven ? 'block' : 'attack',
        });
      }
      if (c.phase == 'player_turn') c.apply({'type': 'end_turn'});
    } else if (phase == 'keystone') {
      if (wantPhase == 'keystone') return true;
      c.apply({'type': 'choose_keystone', 'index': 1});
    } else if (phase == 'reward') {
      if (wantPhase == 'reward') return true;
      c.apply({'type': 'choose_reward', 'index': 1});
    } else if (phase == 'rest') {
      if (wantPhase == 'rest') return true;
      c.apply({'type': 'rest'});
    } else if (phase == 'shop') {
      if (wantPhase == 'shop') return true;
      c.apply({'type': 'leave_shop'});
    } else if (phase == 'event') {
      if (wantPhase == 'event') return true;
      c.apply({'type': 'event_choose', 'option': 1});
    } else {
      break;
    }
  }
  return c.phase == wantPhase;
}

void main() {
  const tablet10 = Size(800, 1280);
  const tablet7 = Size(600, 960);

  testWidgets('tablet plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_tablet_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    // Title (via GameRoot at menu phase).
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    c.meta
      ..tutorialSeen = true
      ..embers = 420
      ..runsPlayed = 31
      ..runsWon = 12
      ..ownedThemes.addAll(hearthThemes.keys)
      ..ownedDieSkins.addAll(dieSkins.keys);
    await capture(tester, GameRoot(c), 'title_800x1280', tablet10);
    await capture(tester, GameRoot(c), 'title_600x960', tablet7);

    // Settings / Ledger / Codex.
    await capture(tester, const SettingsScreen(), 'settings_800x1280', tablet10);
    await capture(tester, LedgerScreen(c), 'ledger_800x1280', tablet10);
    await capture(tester, CodexScreen(c), 'codex_800x1280', tablet10);

    // In-run column screens via a driven controller. Shop first: it's the
    // rarest node kind, so it gets the timeout headroom (first run hit the
    // default 10-minute test timeout while still hunting it).
    for (final want in ['shop', 'boon', 'event', 'reward', 'rest']) {
      final rc = GameController(saveDirOverride: dir.path);
      await tester.binding.runAsync(() => rc.boot());
      rc.meta.tutorialSeen = true;
      var ok = false;
      for (var seed = 7; seed < 27 && !ok; seed++) {
        ok = driveToPhase(rc, want == 'boon' ? 'boon' : want, seed: seed);
      }
      if (!ok) {
        // ignore: avoid_print
        print('PLATE-SKIP: could not reach $want');
        continue;
      }
      await capture(tester, GameRoot(rc), '${want}_800x1280', tablet10);
      // ignore: avoid_print
      print('PLATE-OK: $want');
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
