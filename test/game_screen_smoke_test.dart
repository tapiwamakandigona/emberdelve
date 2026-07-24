// Smoke: gameplay route constructs, and EmberGame.onLoad brings up a real
// LevelSession from the shipped w1_l1 asset (binding-initialized so
// rootBundle works; no rendering/pumping — GameWidget frame loops are flaky
// in headless CI, per M2c escape hatch the route construction is the gate).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/core/save.dart';
import 'package:emberdelve/game/ember_game.dart';
import 'package:emberdelve/ui/app_state.dart';
import 'package:emberdelve/ui/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ember_game_ui_');
    AppState.init(store: SaveStore(baseDirOverride: tmp), save: SaveData());
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('game screen route constructs with all three overlays', () {
    const screen = GameScreen(levelId: 'w1_l1');
    expect(screen.levelId, 'w1_l1');
    // Overlay ids are the GameWidget<->game contract.
    expect(EmberGame.overlayPause, 'pause');
    expect(EmberGame.overlayResults, 'results');
    expect(EmberGame.overlayFail, 'fail');
    expect(const MaterialApp(home: screen), isA<Widget>());
  });

  testWidgets('EmberGame loads the w1_l1 session headlessly', (tester) async {
    final game = EmberGame(levelId: 'w1_l1', seedOverride: 1);
    // Real asset I/O needs runAsync (FakeAsync would deadlock rootBundle).
    await tester.runAsync(() => game.onLoad());
    expect(game.session.level.name, 'Forest Edge');
    expect(game.session.signs.length, 3);
    expect(game.session.enemies.length, 1); // the tutorial thornling
    expect(game.session.signs[0].text, contains('JUMP'));
    expect(game.session.signs[1].text, contains('SWORD'));
    expect(game.session.signs[2].text, contains('DOWN + JUMP'));
    expect(game.session.chestTotal, 1);
  });
}
