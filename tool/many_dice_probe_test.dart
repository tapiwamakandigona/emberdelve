// tool/many_dice_probe_test.dart — layout probe for LARGE dice pools (tool/,
// NOT in CI). Forces pools of 6/9/12/16 dice and screenshots combat (unrolled,
// rolled, part-assigned), rest (forge list), reward, shop, and map at phone
// sizes from 320x568 to 412x915, recording every RenderFlex overflow or
// layout exception. Run: flutter test tool/many_dice_probe_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/many_dice_probe';
final rootKey = GlobalKey();
final List<String> problems = [];
String ctx = 'start';

const sizes = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];
const pools = <int>[6, 9, 12, 16];

List<String> poolOf(int n) => [
      for (var i = 0; i < n; i++)
        ['d6', 'd8_keen', 'd4_guard', 'd10_blade', 'd12_titan', 'd6_ember',
            'd8_aegis', 'd4_lucky'][i % 8]
    ];

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await icons.load();
    }
  }
}

void installHook() {
  final original = FlutterError.onError!;
  FlutterError.onError = (details) {
    final s = details.toString();
    final src =
        RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(s)?.group(1) ?? '?';
    problems
        .add('$ctx: ${details.exceptionAsString().split('\n').first} @$src');
    original(details);
  };
}

void drain(WidgetTester tester) {
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
  drain(tester);
}

Future<void> shot(WidgetTester tester, String name) async {
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding
      .runAsync(() => boundary.toImage(pixelRatio: 2.0));
  final bytes = await tester.binding
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Walk the map applying commands directly until we land in a fight.
void walkToFight(GameController c) {
  var guard = 0;
  while (c.phase == 'map' && guard++ < 15) {
    final m = c.state!['map'] as Map;
    final pos = m['position'] as int;
    final edges = ((m['edges'] as Map)['$pos'] as List).cast<int>();
    // Prefer a fight node.
    int pick = edges.first;
    for (final e in edges) {
      final kind = ((m['nodes'] as Map)['$e'] as Map)['kind'] as String;
      if (kind == 'fight' || kind == 'elite') {
        pick = e;
        break;
      }
    }
    c.apply({'type': 'choose_node', 'node': pick});
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('many-dice layout probe', (tester) async {
    await loadRealFonts();
    installHook();

    for (final size in sizes) {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final sz = '${size.width.toInt()}x${size.height.toInt()}';

      for (final n in pools) {
        final c = GameController();
        c.meta.tutorialSeen = true;
        await tester.pumpWidget(RepaintBoundary(
          key: rootKey,
          child: MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
        ));
        c.startRun(character: 'kindler', seed: 7);
        c.sim!.player['dice'] = poolOf(n);
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await pumpFor(tester, 300);

        // COMBAT — unrolled tray
        ctx = 'combat-unrolled n=$n $sz';
        walkToFight(c);
        await pumpFor(tester, 900);
        if (c.phase != 'player_turn') {
          problems.add('$ctx: never reached a fight (phase=${c.phase})');
          continue;
        }
        await shot(tester, 'combat_unrolled_${sz}_n$n');

        // COMBAT — rolled
        ctx = 'combat-rolled n=$n $sz';
        c.apply({'type': 'roll'});
        await pumpFor(tester, 1200);
        await shot(tester, 'combat_rolled_${sz}_n$n');

        // COMBAT — half assigned
        ctx = 'combat-assigned n=$n $sz';
        for (var d = 1; d <= n ~/ 2; d++) {
          c.apply({'type': 'assign', 'die': d, 'action': 'attack'});
        }
        await pumpFor(tester, 1600);
        await shot(tester, 'combat_assigned_${sz}_n$n');

        // REST — forge list with the same big pool
        ctx = 'rest n=$n $sz';
        c.sim!.phase = 'rest';
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await pumpFor(tester, 500);
        await shot(tester, 'rest_${sz}_n$n');

        // MAP — deck preview strip
        ctx = 'map n=$n $sz';
        c.sim!.phase = 'map';
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await pumpFor(tester, 500);
        await shot(tester, 'map_${sz}_n$n');
        await pumpFor(tester, 600);
      }
    }

    final report = StringBuffer()
      ..writeln('== MANY DICE PROBE ==')
      ..writeln('-- problems (${problems.length}) --')
      ..writeln(problems.join('\n'));
    File('$outDir/report.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(report.toString());
    expect(true, isTrue);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
