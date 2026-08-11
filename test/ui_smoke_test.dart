import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/main.dart';
import 'package:emberwood/ui/app_state.dart';
import 'package:emberwood/ui/level_select_screen.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ember_ui_');
    AppState.init(store: SaveStore(baseDirOverride: tmp), save: SaveData());
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('title screen renders and navigates to level select',
      (tester) async {
    await tester.pumpWidget(const EmberwoodApp());
    expect(find.text('EMBERDELVE'), findsOneWidget);
    await tester.tap(find.text('PLAY'));
    // M4 title runs a looping parallax drift — pumpAndSettle would never
    // settle; pump the route transition explicitly instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WORLD 1 — EMBERWOOD'), findsOneWidget);
    expect(find.text('Forest Edge'), findsOneWidget);
  });

  testWidgets('level select locks later levels', (tester) async {
    // Tall surface so the lazy ListView builds both world sections.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();
    // 5 locked in W1 + all 6 locked in the gated W2 section.
    expect(find.byIcon(Icons.lock), findsNWidgets(11));
    AppState.save.recordFor('w1_l1').finished = true;
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsNWidgets(10));
  });
}
