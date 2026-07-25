// hud_routing_test.dart — pointer-event ROUTING tests for the touch HUD.
//
// Regression tests for the v1.0.0-alpha.3 touch-input fix. The old hold-button
// tests called onTapDown()/onDragStart() directly on the component, so they
// verified the button state machine but never the delivery pipeline. Both real
// bugs lived in that pipeline:
//
//   1. Gesture recognizers were registered only when the first HUD button
//      mounted (after the GameWidget's first build) and never attached in
//      release builds -> EmberGame now registers its dispatchers + recognizers
//      at construction time and forwards taps/drags itself (game-level
//      MultiTouchTapDetector/MultiTouchDragDetector APIs).
//   2. The hidden throw button (scale = 0 when applesHeld == 0) swallowed
//      every tap: a singular transform collapses every canvas point to local
//      (0,0), which containsLocalPoint(0,0) accepted. It sits before the
//      arrow buttons in reversed hit-test order, so left/right were dead
//      while jump/attack/pause (checked earlier) kept working.
//
// These tests drive the REAL pipeline from the game-level gesture API
// (exactly what Flutter's recognizers call): handleTapDown -> dispatcher ->
// componentsAtPoint -> HudHoldButton -> touchLeft/touchRight -> movement.
import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/core/save.dart';
import 'package:emberdelve/game/components/hud.dart';
import 'package:emberdelve/game/ember_game.dart';
import 'package:emberdelve/ui/app_state.dart';

/// Boots a fully mounted game the same way GameWidget would, headlessly.
Future<EmberGame> bootGame() async {
  AppState.diskWrites = false;
  AppState.init(store: SaveStore(), save: SaveData(tutorialSeen: true));
  final game = EmberGame(levelId: 'w1_l1', seedOverride: 42);
  game.onGameResize(Vector2(800, 450));
  await game.onLoad();
  game.mount();
  // Buttons load their sprites asynchronously; wait for the whole tree.
  await game.ready();
  game.update(0);
  return game;
}

/// Canvas point (800x450 canvas -> viewWidth x viewHeight view) of a view
/// point. Derived from EmberGame's constants so camera-zoom changes (AKP-1)
/// never silently invalidate these routing tests.
Offset canvasPoint(double vx, double vy) => Offset(
    vx * 800 / EmberGame.viewWidth, vy * 800 / EmberGame.viewWidth);

/// Canvas-space centre of the HUD button using [spritePath] — geometry is
/// read from the mounted game, not hard-coded, so layout passes (AKP-5)
/// keep these tests honest: they verify ROUTING, not pixel positions.
Offset buttonCentre(EmberGame game, String spritePath) {
  final b = game.camera.viewport.children
      .whereType<HudHoldButton>()
      .firstWhere((c) => c.spritePath == spritePath);
  return canvasPoint(b.position.x + b.size.x / 2, b.position.y + b.size.y / 2);
}

TapDownDetails tapDown(Offset global) =>
    TapDownDetails(globalPosition: global, localPosition: global);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hit test resolves the arrow buttons, not the hidden throw button',
      () async {
    final game = await bootGame();
    final rightBtn = buttonCentre(game, 'hud/btn_right.png');
    expect(game.session.applesHeld, 0, reason: 'no apples at spawn');
    final hitsRight = game
        .componentsAtPoint(Vector2(rightBtn.dx, rightBtn.dy))
        .toList();
    expect(hitsRight.whereType<HudHoldButton>(), isNotEmpty,
        reason: 'an arrow button must be hittable');
    expect(hitsRight.whereType<HudThrowButton>(), isEmpty,
        reason: 'hidden throw button must not swallow taps (alpha.2 bug)');
    // Nothing anywhere on screen may hit the hidden throw button.
    final centre = game.componentsAtPoint(Vector2(400, 225)).toList();
    expect(centre.whereType<HudThrowButton>(), isEmpty);
  });

  test('held tap on right/left arrows moves the player', () async {
    final game = await bootGame();
    final rightBtn = buttonCentre(game, 'hud/btn_right.png');
    final leftBtn = buttonCentre(game, 'hud/btn_left.png');
    final x0 = game.session.player.body.centerX;

    // Press right arrow via the real game-level gesture API.
    game.handleTapDown(1, tapDown(rightBtn));
    expect(game.touchRight, isTrue,
        reason: 'tapDown on the right arrow must set touchRight');
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    final xHeld = game.session.player.body.centerX;
    expect(xHeld, greaterThan(x0 + 10),
        reason: 'player must move right while held');
    game.handleTapUp(
        1, TapUpDetails(kind: PointerDeviceKind.touch,
            globalPosition: rightBtn, localPosition: rightBtn));
    expect(game.touchRight, isFalse, reason: 'release must clear touchRight');

    // Left arrow.
    game.handleTapDown(2, tapDown(leftBtn));
    expect(game.touchLeft, isTrue);
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    expect(game.session.player.body.centerX, lessThan(xHeld - 10),
        reason: 'player must move left while held');
    game.handleTapUp(
        2, TapUpDetails(kind: PointerDeviceKind.touch,
            globalPosition: leftBtn, localPosition: leftBtn));
    expect(game.touchLeft, isFalse);
  });

  test('thumb drift (tap cancel -> drag takeover) keeps the button held',
      () async {
    final game = await bootGame();
    final rightBtn = buttonCentre(game, 'hud/btn_right.png');
    final x0 = game.session.player.body.centerX;

    // Real arena sequence when a held thumb drifts past the touch slop:
    // tapDown ... tapCancel immediately followed by dragStart (same stack).
    game.handleTapDown(3, tapDown(rightBtn));
    expect(game.touchRight, isTrue);
    for (var i = 0; i < 10; i++) {
      game.update(1 / 60);
    }
    game.handleTapCancel(3);
    game.handleDragStart(
        0,
        DragStartDetails(
            sourceTimeStamp: Duration.zero,
            globalPosition: rightBtn,
            localPosition: rightBtn));
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
    }
    expect(game.touchRight, isTrue,
        reason: 'drift must not release the held button (alpha.1 bug)');
    expect(game.session.player.body.centerX, greaterThan(x0 + 10));
    game.handleDragEnd(0, DragEndDetails());
    game.update(1 / 60);
    expect(game.touchRight, isFalse,
        reason: 'lifting the drifted thumb must stop movement');
  });

  test('genuine tap cancel (no drag takeover) releases within one frame',
      () async {
    final game = await bootGame();
    final leftBtn = buttonCentre(game, 'hud/btn_left.png');
    game.handleTapDown(4, tapDown(leftBtn));
    expect(game.touchLeft, isTrue);
    game.handleTapCancel(4); // e.g. app backgrounded — no dragStart follows
    game.update(1 / 60); // tick parks -> releases
    game.update(1 / 60);
    expect(game.touchLeft, isFalse);
  });
}
