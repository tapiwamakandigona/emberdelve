// hud_layout_test.dart — AKP-5 acceptance: AK-style control layout.
//
// Verifies the plan's DoD (docs/ak-parity-plan.md §5) against the REAL
// mounted HUD, not constants: every touch target >= 44 logical px (48dp
// equivalent at the 384x216 view), no two buttons overlap, the new dash and
// down buttons actually drive their verbs through the full tap-routing
// pipeline, and the spawn-fade keeps the movement cluster translucent for
// the first second.
import 'dart:ui' show Rect;

import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/core/save.dart';
import 'package:emberdelve/game/components/hud.dart';
import 'package:emberdelve/game/ember_game.dart';
import 'package:emberdelve/game/player/player_core.dart' show PlayerState;
import 'package:emberdelve/ui/app_state.dart';

Future<EmberGame> bootGame() async {
  AppState.diskWrites = false;
  AppState.init(store: SaveStore(), save: SaveData(tutorialSeen: true));
  final game = EmberGame(levelId: 'w1_l1', seedOverride: 42);
  game.onGameResize(Vector2(800, 450));
  await game.onLoad();
  game.mount();
  await game.ready();
  game.update(0);
  return game;
}

List<HudHoldButton> buttons(EmberGame game) =>
    game.camera.viewport.children.whereType<HudHoldButton>().toList();

HudHoldButton byPath(EmberGame game, String spritePath) =>
    buttons(game).firstWhere((b) => b.spritePath == spritePath);

HudHoldButton byIcon(EmberGame game, String iconPath) =>
    buttons(game).firstWhere((b) => b.iconPath == iconPath);

Rect rectOf(HudHoldButton b) =>
    Rect.fromLTWH(b.position.x, b.position.y, b.size.x, b.size.y);

Offset canvasPoint(double vx, double vy) => Offset(
    vx * 800 / EmberGame.viewWidth, vy * 800 / EmberGame.viewWidth);

Offset centreOf(HudHoldButton b) =>
    canvasPoint(b.position.x + b.size.x / 2, b.position.y + b.size.y / 2);

TapDownDetails tapDown(Offset global) =>
    TapDownDetails(globalPosition: global, localPosition: global);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every touch target is >= 44 logical px and inside the view', () async {
    final game = await bootGame();
    final all = buttons(game);
    expect(all.length, 8,
        reason: 'left, right, down, dash, sword, jump, apple, pause');
    for (final b in all) {
      expect(b.size.x, greaterThanOrEqualTo(44),
          reason: '${b.spritePath}/${b.iconPath} narrower than 44px');
      expect(b.size.y, greaterThanOrEqualTo(44));
      final r = rectOf(b);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(EmberGame.viewWidth));
      expect(r.bottom, lessThanOrEqualTo(EmberGame.viewHeight));
    }
  });

  test('no two HUD buttons overlap', () async {
    final game = await bootGame();
    final all = buttons(game);
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final a = rectOf(all[i]), b = rectOf(all[j]);
        expect(a.overlaps(b), isFalse,
            reason: '${all[i].spritePath}/${all[i].iconPath} overlaps '
                '${all[j].spritePath}/${all[j].iconPath}');
      }
    }
  });

  test('diamond reads AK-style: jump biggest, bottom-right corner', () async {
    final game = await bootGame();
    final jump = byIcon(game, 'hud/icon_jump.png');
    final sword = byIcon(game, 'hud/icon_sword.png');
    final dash = byIcon(game, 'hud/icon_dash.png');
    for (final other in buttons(game)) {
      if (identical(other, jump)) continue;
      expect(jump.size.x, greaterThanOrEqualTo(other.size.x),
          reason: 'jump must be the biggest button');
    }
    // Jump anchors the corner; sword sits left of it, dash above the sword.
    expect(rectOf(jump).right, EmberGame.viewWidth - 8);
    expect(rectOf(sword).right, lessThanOrEqualTo(rectOf(jump).left));
    expect(rectOf(dash).bottom, lessThanOrEqualTo(rectOf(sword).top));
  });

  test('dash button press rolls the player (full routing pipeline)', () async {
    final game = await bootGame();
    // Land + settle first so the player is grounded.
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    game.session.player.takeEvents();
    final dash = byIcon(game, 'hud/icon_dash.png');
    game.handleTapDown(9, tapDown(centreOf(dash)));
    game.update(1 / 60);
    game.update(1 / 60);
    // NOTE: EmberGame.update drains PlayerEvents for sfx/fx every frame,
    // so assert on the state machine, not takeEvents().
    expect(game.session.player.state, PlayerState.roll,
        reason: 'dash button must start the commit-dodge');
  });

  test('down button holds touchDown (peek/drop-through verb, AKP-2c)',
      () async {
    final game = await bootGame();
    final down = byPath(game, 'hud/btn_down.png');
    game.handleTapDown(11, tapDown(centreOf(down)));
    expect(game.touchDown, isTrue,
        reason: 'down chevron must finally wire touchDown');
    game.handleTapUp(
        11,
        TapUpDetails(
            kind: PointerDeviceKind.touch,
            globalPosition: centreOf(down),
            localPosition: centreOf(down)));
    expect(game.touchDown, isFalse);
  });

  test('movement cluster fades for the first second after spawn', () async {
    final game = await bootGame();
    final left = byPath(game, 'hud/btn_left.png');
    final jump = byIcon(game, 'hud/icon_jump.png');
    game.update(1 / 60);
    final fadedAlpha = left.paint.color.a;
    expect(fadedAlpha, lessThan(0.3),
        reason: 'arrows must fade while the player spawns behind them');
    expect(jump.paint.color.a, greaterThan(0.5),
        reason: 'non-movement buttons do not spawn-fade');
    // After the fade window the idle opacity (~0.55, AKP-5c) is restored.
    for (var i = 0; i < 70; i++) {
      game.update(1 / 60);
    }
    expect(left.paint.color.a, closeTo(0.55, 0.02));
  });
}
