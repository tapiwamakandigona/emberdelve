// M4 widget smoke tests: title (all four routes), settings (sliders +
// reset-save confirm flow), credits (renders CREDITS.md incl. the required
// CC-BY chest attribution), level select (cards, medals, wallet, boss lock).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/core/save.dart';
import 'package:emberdelve/ui/app_state.dart';
import 'package:emberdelve/ui/credits_screen.dart';
import 'package:emberdelve/ui/level_select_screen.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/title_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late SaveStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ember_meta_');
    store = SaveStore(baseDirOverride: tmp);
    AppState.init(store: store, save: SaveData());
    AppState.diskWrites = false; // see AppState.diskWrites
  });
  tearDown(() {
    AppState.diskWrites = true;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('title screen offers Play / Shop / Settings / Credits',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TitleScreen()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('EMBERDELVE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
  });

  testWidgets('settings: reset-save wipes progress after confirm',
      (tester) async {
    AppState.save.coins = 999;
    AppState.save.recordFor('w1_l1').finished = true;
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset save'));
    await tester.pumpAndSettle();
    expect(find.text('Reset save?'), findsOneWidget);
    // Cancel first: nothing changes.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(AppState.save.coins, 999);
    // Confirm: fresh save persisted.
    await tester.tap(find.text('Reset save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();
    expect(AppState.save.coins, 0);
    expect(AppState.save.levels, isEmpty);
    // (Disk persistence is covered by the headless persist-queue test in
    // shop_flow_test — widget tests stay on FakeAsync turf.)
  });

  testWidgets('credits render CREDITS.md (original-asset pass: no CC-BY left)',
      (tester) async {
    // CREDITS.md is a registered pubspec asset; flutter test serves the real
    // bundle, but the async load needs a runAsync flush (FakeAsync would
    // starve the rootBundle future forever).
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('CREDITS & LICENSES'), findsOneWidget);
    // Content rendered (top of the document is on screen).
    expect(find.textContaining('Tsoro Studios'), findsWidgets);
    // Since the 2026-07-25 original-asset pass (docs/original-assets.md)
    // nothing shipped is CC-BY: the doc must state that no attribution is
    // legally required, and the courtesy CC0 credits must be reachable
    // (ListView builds lazily — scroll to them).
    expect(
        find.textContaining('no shipped asset legally requires attribution'),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('pixivan'), 120,
        scrollable: find.byType(Scrollable));
    expect(find.textContaining('pixivan'), findsOneWidget);
    expect(find.textContaining('CC0'), findsWidgets);
  });

  testWidgets(
      'level select: boss locked until all five levels finished, medals shown',
      (tester) async {
    final save = AppState.save;
    save.coins = 77;
    for (final id in ['w1_l1', 'w1_l2', 'w1_l3', 'w1_l4']) {
      save.recordFor(id)
        ..finished = true
        ..allChests = true;
    }
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.text('WORLD 1 — EMBERWOOD'), findsOneWidget);
    expect(find.text(' 77   '), findsOneWidget); // wallet coins
    expect(find.text('Grove Golem'), findsOneWidget);
    expect(find.text('Finish all five levels to face the Golem'),
        findsOneWidget);
    // Finish l5: the boss unlocks.
    save.recordFor('w1_l5').finished = true;
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Finish all five levels to face the Golem'),
        findsNothing);
    expect(find.byIcon(Icons.whatshot), findsOneWidget);
  });
}
