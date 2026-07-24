// tool/store_screenshots_test.dart — Play-listing screenshot harness.
// NOT part of the CI gate (lives in tool/). Run explicitly:
//
//   flutter test tool/store_screenshots_test.dart
//
// Renders real screens (GameController-driven, real Cinzel/Inter and the
// Material icon font, so nothing shows as boxes) at 360x640 logical / 3.0
// pixel ratio = 1080x1920 PNGs (Play's preferred 9:16), written to
// docs/store/screenshots/. Deterministic: fixed seeds, fixed meta.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/logo.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

const outDir = 'docs/store/screenshots';
const shotSize = Size(360, 640); // x3.0 => 1080x1920 (9:16)
const pixelRatio = 3.0;
final rootKey = GlobalKey();

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  // Material icon glyphs come from the Flutter SDK cache, not app assets.
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

Widget app(Widget home) => RepaintBoundary(
      key: rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: home,
      ),
    );

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    // Let real async work (rootBundle sprite loads, asset image decode)
    // actually complete between frames — plain pump() never runs it.
    await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: step));
    tester.takeException(); // keep walking; screenshots, not a gate
  }
}

/// Decode every asset image the shots need, so nothing paints as a blank.
Future<void> precacheArt(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  final assets = <String>[
    Art.bgTitle, Art.bgMap, Art.bgCombat, Art.bgBoss,
    Art.currencyCoin, Art.currencyEmber, Art.currencyInsight,
    ...Art.nodeIcons.values,
  ];
  await tester.binding.runAsync(() async {
    for (final a in assets) {
      try {
        await precacheImage(AssetImage(a), context);
      } catch (_) {}
    }
  });
  await tester.pump();
}

Future<void> snap(WidgetTester tester, String name,
    {double ratio = pixelRatio}) async {
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding
      .runAsync(() => boundary.toImage(pixelRatio: ratio));
  final bytes = await tester.binding
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('$outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $outDir/$name.png (${image!.width}x${image.height})');
}

/// A believable mid-game meta so screens don't look empty/first-boot.
GameController richController() {
  final c = GameController();
  final m = c.meta
    ..tutorialSeen = true
    ..embers = 214
    ..runsPlayed = 23
    ..runsWon = 9
    ..bestAscension = 2
    ..lifetimeEmbers = 1240
    ..exactKills = 31
    ..bestExactStreak = 4
    ..charRuns = {'kindler': 14, 'warden': 6, 'gambler': 3}
    ..charWins = {'kindler': 6, 'warden': 2, 'gambler': 1};
  m.unlockedCharacters.addAll({'warden', 'gambler'});
  const chars = ['kindler', 'warden', 'gambler'];
  const results = ['won', 'lost', 'lost', 'won', 'lost'];
  for (var i = 0; i < 5; i++) {
    m.addRunRecord({
      'date': '2026-07-${23 - i}',
      'character': chars[i % chars.length],
      'difficulty': i == 1 ? 'hard' : 'normal',
      'result': results[i],
      'floor': results[i] == 'won' ? 12 : 5 + i,
      'floors': 12,
      'seed': 100000 + i * 7717,
      'embers': 40 + i * 9,
      'daily': i == 2,
    });
  }
  return c;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('store screenshots', (tester) async {
    tester.view.physicalSize = shotSize * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    tester.view.physicalSize = shotSize * pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = richController();

    // 1 — title (camp fire + logotype).
    await tester.pumpWidget(app(GameRoot(c)));
    await precacheArt(tester);
    await pumpFor(tester, 1400);
    await snap(tester, '01-title');

    // 2 — starting boon pick.
    c.startRun(character: 'kindler', seed: 7, boons: true);
    await pumpFor(tester, 900);
    await snap(tester, '02-boon-pick');

    // 3 — the map after the pick.
    c.apply({'type': 'choose_boon', 'index': 1});
    await pumpFor(tester, 1500);
    await snap(tester, '03-map');

    // A mid-run pool: more interesting combat tray than 3 starter d6s.
    (c.state!['player'] as Map)['dice'] = <String>[
      'd6', 'd6', 'd8_aegis', 'd10_blade', 'd4_lucky',
    ];

    // 4/5 — walk to the first fight; shoot rolled dice, then the enemy
    // intent after a partial assignment.
    var guard = 0;
    var shotCombat = false, shotShop = false;
    while (guard++ < 40 && c.phase != null && !(shotCombat && shotShop)) {
      final phase = c.phase;
      if (phase == 'map') {
        final map = c.state!['map'] as Map;
        final position = map['position'] as int;
        final edges =
            ((map['edges'] as Map)['$position'] as List).cast<int>();
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        int pick = edges.first;
        for (final e in edges) {
          final kind = nodes['$e']!['kind'] as String;
          if (!shotCombat && (kind == 'fight' || kind == 'elite')) {
            pick = e;
            break;
          }
          if (!shotShop && kind == 'shop') pick = e;
        }
        c.apply({'type': 'choose_node', 'node': pick});
        await pumpFor(tester, 900);
      } else if (phase == 'player_turn') {
        c.apply({'type': 'roll'});
        await pumpFor(tester, 2200); // let the tumble fully settle
        if (!shotCombat) {
          await snap(tester, '04-combat-roll');
          shotCombat = true;
        }
        final player = c.state!['player'] as Map;
        final n = (player['dice'] as List).length;
        for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
          c.apply({
            'type': 'assign',
            'die': i,
            'action': i.isEven ? 'block' : 'attack',
          });
        }
        await pumpFor(tester, 400);
        if (c.phase == 'player_turn') {
          c.apply({'type': 'end_turn'});
          await pumpFor(tester, 1400);
        }
      } else if (phase == 'reward') {
        await pumpFor(tester, 300);
        c.apply({'type': 'choose_reward', 'index': 1});
        await pumpFor(tester, 300);
      } else if (phase == 'shop') {
        await pumpFor(tester, 700);
        if (!shotShop) {
          await snap(tester, '05-shop');
          shotShop = true;
        }
        c.apply({'type': 'leave_shop'});
        await pumpFor(tester, 300);
      } else if (phase == 'rest') {
        c.apply({'type': 'rest'});
        await pumpFor(tester, 300);
      } else if (phase == 'event') {
        await pumpFor(tester, 300);
        c.apply({'type': 'event_choose', 'option': 1});
        await pumpFor(tester, 300);
      } else {
        break;
      }
    }

    // 6 — the Ledger (lifetime stats + recent delves).
    await tester.pumpWidget(app(LedgerScreen(c)));
    await pumpFor(tester, 800);
    await snap(tester, '05-ledger');

    await pumpFor(tester, 2000); // drain timers
  });

  testWidgets('feature graphic 1024x500', (tester) async {
    const size = Size(512, 250); // x2.0 => 1024x500
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = size * 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(RepaintBoundary(
      key: rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: Scaffold(
          body: Stack(fit: StackFit.expand, children: [
            Image.asset(Art.bgBoss, fit: BoxFit.cover),
            // Legibility scrim + ember glow from the bottom.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA14101E), Color(0x5514101E)],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmberLogotype('EMBERDELVE', fontSize: 52),
                const SizedBox(height: 6),
                Text('Fair dice. Real choices. Delve in.',
                    style: EmberText.body
                        .copyWith(fontSize: 15, letterSpacing: 1.1)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                        width: 56,
                        child: DieChip('d6', value: 6)),
                    SizedBox(width: 14),
                    SizedBox(
                        width: 56,
                        child: DieChip('d8_aegis', value: 7)),
                    SizedBox(width: 14),
                    SizedBox(
                        width: 56,
                        child: DieChip('d10_blade', value: 10, maxed: true)),
                  ],
                ),
              ],
            ),
          ]),
        ),
      ),
    ));
    await precacheArt(tester);
    await pumpFor(tester, 1200);
    await snap(tester, 'feature-graphic-1024x500', ratio: 2.0);
    await pumpFor(tester, 1500);
  });
}
