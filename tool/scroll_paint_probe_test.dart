// tool/scroll_paint_probe_test.dart — probe: painter census WHILE FLINGING
// the two long lists (roster, map) at 360×800. Names painter classes so any
// per-frame repaint of a big surface stands out. Not part of CI.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/provings_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

GameController seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion
    ..runsPlayed = 3;
  return c;
}

Future<void> flingCensus(
  WidgetTester tester,
  String name,
  Finder scrollable,
) async {
  var frames = 0;
  var paints = 0;
  final byType = <String, int>{};
  debugOnProfilePaint = (RenderObject ro) {
    paints++;
    var t = ro.runtimeType.toString();
    if (ro is RenderCustomPaint) {
      t = '$t<${ro.painter?.runtimeType ?? ro.foregroundPainter?.runtimeType}>';
    }
    if (ro is RenderParagraph) t = 'RenderParagraph';
    byType[t] = (byType[t] ?? 0) + 1;
  };
  final gesture = await tester.startGesture(tester.getCenter(scrollable));
  for (var i = 0; i < 60; i++) {
    await gesture.moveBy(const Offset(0, -12));
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  await gesture.up();
  debugOnProfilePaint = null;
  final top = byType.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  // ignore: avoid_print
  print(
    '$name SCROLL frames=$frames paints=$paints (${(paints / frames).toStringAsFixed(1)}/frame)\n  ${top.take(16).map((e) => '${e.key}: ${e.value}').join('\n  ')}',
  );
}

Future<void> idleCensus(WidgetTester tester, String name) async {
  var paints = 0;
  final byType = <String, int>{};
  debugOnProfilePaint = (RenderObject ro) {
    paints++;
    var t = ro.runtimeType.toString();
    if (ro is RenderCustomPaint) {
      t = '$t<${ro.painter?.runtimeType ?? ro.foregroundPainter?.runtimeType}>';
    }
    byType[t] = (byType[t] ?? 0) + 1;
  };
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  debugOnProfilePaint = null;
  final top = byType.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  // ignore: avoid_print
  print(
    '$name frames=60 paints=$paints (${(paints / 60).toStringAsFixed(1)}/frame)\n  ${top.take(16).map((e) => '${e.key}: ${e.value}').join('\n  ')}',
  );
}

void main() {
  testWidgets('roster scroll census', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await flingCensus(tester, 'ROSTER', find.byType(Scrollable).last);
  });

  testWidgets('map scroll census', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    c.startRun(character: 'kindler', seed: 11, boons: false);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('phase ${c.phase}');
    // Idle first, then flinging.
    await idleCensus(tester, 'MAP-IDLE');
    await flingCensus(tester, 'MAP', find.byType(Scrollable).first);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('summary scroll census', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    c.startRun(
      character: 'kindler',
      seed: 7,
      boons: false,
      difficulty: 'normal',
    );
    var guard = 0;
    while (guard++ < 4000 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Scaffold(body: SummaryScreen(c)),
      ),
    );
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await flingCensus(tester, 'SUMMARY', find.byType(Scrollable).first);
  });

  for (final target in const ['rest', 'shop']) {
    testWidgets('$target scroll census', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = seasoned();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      c.startRun(
        character: 'kindler',
        seed: target == 'rest' ? 11 : 7,
        boons: false,
      );
      (c.state!['player'] as Map)['dice'] = <String>[
        for (final d in diceOrder.take(10)) d,
      ];
      var guard = 0;
      while (guard++ < 40 && c.phase == 'map') {
        final map = c.state!['map'] as Map;
        final position = map['position'] as int;
        final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        final hit = edges.where((e) => nodes['$e']!['kind'] == target);
        if (hit.isEmpty) break;
        c.apply({'type': 'choose_node', 'node': hit.first});
      }
      // ignore: avoid_print
      print('phase ${c.phase}');
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (c.phase == target) {
        await flingCensus(
          tester,
          target.toUpperCase(),
          find.byType(Scrollable).first,
        );
      }
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  }

  for (final (name, build) in <(String, Widget Function(GameController))>[
    ('CODEX', (c) => CodexScreen(c)),
    ('PROVINGS', (c) => ProvingsScreen(c)),
    ('LEDGER', (c) => LedgerScreen(c)),
  ]) {
    testWidgets('$name scroll census', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = seasoned();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: build(c)),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await flingCensus(tester, name, find.byType(Scrollable).last);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  }
}
