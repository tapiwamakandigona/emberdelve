// test/centered_hollow_test.dart — v0.180.0 "The Centered Hollow".
//
// When the hollow has dice to forge it lays out as one stretched ListView,
// and the title 'A warm hollow' sat flush against the left screen edge. It
// is centered in both branches now.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('hollow title is centered when the forge list is showing', (
    tester,
  ) async {
    const size = Size(360, 800);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta
      ..tourSeenVersion = tourVersion
      ..tutorialSeen = true
      ..tipsSeen.addAll(ContextTips.all)
      ..lastSeenNewsVersion = currentAppVersion;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: GameRoot(c),
        ),
      ),
    );
    await pumpFor(tester, 300);
    c.startRun(character: 'kindler', seed: 11, boons: true);
    await pumpFor(tester, 300);
    c.apply({'type': 'choose_boon', 'index': 1});
    // A forgeable pool, then walk to the nearest rest node.
    (c.state!['player'] as Map)['dice'] = <String>[
      for (final d in diceOrder.take(6)) d,
    ];
    var guard = 0;
    while (guard++ < 40 && c.phase == 'map') {
      final map = c.state!['map'] as Map;
      final position = map['position'] as int;
      final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
      final nodes = (map['nodes'] as Map).cast<String, Map>();
      final rest = edges.where((e) => nodes['$e']!['kind'] == 'rest');
      if (rest.isEmpty) break;
      c.apply({'type': 'choose_node', 'node': rest.first});
    }
    // Seed 11 offers a rest node on the first edge; keep the seed if this
    // ever fails rather than weakening the assertion.
    expect(c.phase, 'rest');
    await pumpFor(tester, 600);
    final title = find.text('A warm hollow');
    expect(title, findsOneWidget);
    final r = tester.getRect(title);
    // The rendered box is stretched; the painted text must be centered.
    final text = tester.widget<Text>(title);
    expect(text.textAlign, TextAlign.center);
    expect(r.left, greaterThanOrEqualTo(0));
    expect(find.byType(ListView), findsWidgets);
    await pumpFor(tester, 1200);
  });
}
