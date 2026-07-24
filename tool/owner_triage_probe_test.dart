// tool/owner_triage_probe_test.dart — reproduction + verification probe for
// the 2026-07-24 owner screenshot triage (tool/, NOT in CI):
//   1. intent+burn badges must never cover the enemy HP panel on squeezed
//      stages (they now clamp to the stage's headroom),
//   2. unrolled dice / boon die cards must show an engraved size numeral,
//      never a blank cream shape,
//   3. the d4 shows rolled values as an engraved numeral inside the triangle
//      (square pip layouts used to spill off the silhouette).
// Run: flutter test tool/owner_triage_probe_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

const outDir = 'build/owner_triage_probe';
final rootKey = GlobalKey();
final List<String> problems = [];
String ctx = 'start';

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
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
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
    problems.add(
      '$ctx: ${details.exceptionAsString().split('\n').first} @$src',
    );
    original(details);
  };
}

void drain(WidgetTester tester) {
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

Future<void> precacheAllImages(WidgetTester tester) async {
  final manifest = await tester.binding.runAsync(
    () => AssetManifest.loadFromAssetBundle(rootBundle),
  );
  final keys = manifest!.listAssets().where((k) => k.endsWith('.png')).toList();
  final context = tester.element(find.byType(MaterialApp));
  await tester.binding.runAsync(() async {
    for (final k in keys) {
      try {
        await precacheImage(AssetImage(k), context);
      } catch (_) {
        /* ignore */
      }
    }
  });
  await tester.pump();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
  drain(tester);
}

Future<void> shot(WidgetTester tester, String name) async {
  // Let async sprite/image decodes commit before capturing (SpriteView loads
  // ui.Images off the frame pipeline; without this the first combat shot can
  // show an empty stage — a harness artifact, not a game bug).
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pump();
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2.0),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void walkToFight(GameController c) {
  var guard = 0;
  while (c.phase == 'map' && guard++ < 15) {
    final m = c.state!['map'] as Map;
    final pos = m['position'] as int;
    final edges = ((m['edges'] as Map)['$pos'] as List).cast<int>();
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

/// Assert the intent badge (and burn pill) stay clear of both StatBars.
void checkBadgeClearOfHpBars(WidgetTester tester, String label) {
  final badges = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_IntentBadge',
  );
  if (badges.evaluate().isEmpty) {
    problems.add('$label: no intent badge found');
    return;
  }
  final badgeRect = tester.getRect(badges.first);
  for (final bar in find.byType(StatBar).evaluate()) {
    final barRect = (bar.renderObject as RenderBox).let((b) {
      final origin = b.localToGlobal(Offset.zero);
      return origin & b.size;
    });
    if (badgeRect.overlaps(barRect)) {
      problems.add('$label: intent badge $badgeRect overlaps StatBar $barRect');
    }
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner triage probe', (tester) async {
    await loadRealFonts();
    installHook();

    // Squeezed short screen first — the size class where the badge escaped
    // the stage — plus a mid size for sanity.
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final sz = '${size.width.toInt()}x${size.height.toInt()}';

      final c = GameController();
      c.meta.tutorialSeen = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: GameRoot(c),
          ),
        ),
      );
      await precacheAllImages(tester);
      c.startRun(character: 'kindler', seed: 7, boons: true);

      // BOON SCREEN — die boon cards must show a die, not a blank square.
      ctx = 'boon $sz';
      if (c.phase == 'boon') {
        await pumpFor(tester, 600);
        await shot(tester, 'boon_$sz');
        c.apply({'type': 'choose_boon', 'index': 0});
      }

      // Fat mixed pool incl. d4s so the tray wraps and squeezes the stage.
      c.sim!.player['dice'] = [
        'd4_lucky',
        'd4_guard',
        'd6',
        'd6_ember',
        'd8_keen',
        'd8_aegis',
        'd10_blade',
        'd12_titan',
        'd6',
        'd4_lucky',
        'd8_keen',
        'd6_ember',
      ];
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 300);

      ctx = 'combat-unrolled $sz';
      walkToFight(c);
      await pumpFor(tester, 900);
      if (c.phase != 'player_turn') {
        problems.add('$ctx: never reached a fight (phase=${c.phase})');
        continue;
      }
      // Force burn stacks so the wide badge row (intent + burn) renders.
      c.sim!.enemy!['burn'] = 3;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 400);
      await shot(tester, 'combat_unrolled_burn_$sz');
      checkBadgeClearOfHpBars(tester, 'combat-unrolled $sz');

      ctx = 'combat-rolled $sz';
      c.apply({'type': 'roll'});
      await pumpFor(tester, 1200);
      await shot(tester, 'combat_rolled_burn_$sz');
      checkBadgeClearOfHpBars(tester, 'combat-rolled $sz');
    }

    final report = StringBuffer()
      ..writeln('== OWNER TRIAGE PROBE ==')
      ..writeln('-- problems (${problems.length}) --')
      ..writeln(problems.join('\n'));
    File('$outDir/report.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(report.toString());
    stdout.writeln(report);
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
