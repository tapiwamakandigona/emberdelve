// Smoke: gameplay route constructs, and EmberGame.onLoad brings up a real
// LevelSession from the shipped w1_l1 asset (binding-initialized so
// rootBundle works; no rendering/pumping — GameWidget frame loops are flaky
// in headless CI, per M2c escape hatch the route construction is the gate).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/game/ember_game.dart';
import 'package:emberwood/ui/app_state.dart';
import 'package:emberwood/ui/game_screen.dart';

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
    // CHECK CHANGE (2026-07-25 alpha pass): the tutorial teaches four verbs
    // now — the campfire checkpoint is a new one, and it is taught BEFORE the
    // first hazard, which is the whole point of the teach-then-test rework.
    expect(game.session.signs.length, 4);
    expect(game.session.signs[0].text, contains('JUMP'));
    expect(game.session.signs[1].text, contains('campfire'));
    expect(game.session.signs[2].text, contains('SWORD'));
    // AKP-2a: roll is taught via its dedicated button now (chord still works).
    expect(game.session.signs[3].text, contains('DASH'));
    // Two thornlings, both well past the safe runway.
    expect(game.session.enemies.length, 2);
    expect(game.session.checkpoints.length, 2,
        reason: 'the tutorial must demonstrate a checkpoint being lit');
    // Content quotas: 2 plain chests + 2 secret chests behind cracked walls.
    expect(game.session.chestTotal, 4);
    expect(game.session.chests.where((c) => c.secret).length, 2);
  });
}
