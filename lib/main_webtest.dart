// main_webtest.dart — web-only test harness entrypoint.
//
// The production save/settings layer (lib/core/save.dart, lib/audio/settings.dart)
// uses dart:io + path_provider, which throw at runtime on the web, so the normal
// main() can never boot in a browser. This entrypoint exists purely so automated
// browser tests (Playwright/CI) can exercise the real gameplay code:
//   * in-memory save (AppState.diskWrites = false, no file IO ever runs)
//   * no audio service (AudioService.instance stays null; all call sites are `?.`)
//   * boots straight into a level (default w1_l1, or ?level=w1_l3 in the URL)
//     with a fixed seed for deterministic runs
//   * publishes live telemetry to JS every 50ms so tests can assert on real
//     simulation state instead of pixels:
//       window.__emberdelve = { loaded, x, y, hp, coins }
//
// Build:  flutter build web --release -t lib/main_webtest.dart
// Serve:  any static file server over build/web
// NOT part of the Android app; nothing in lib/main.dart imports this file.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';


import 'core/save.dart';
import 'game/ember_game.dart';
import 'meta/catalog.dart' show kWeapons;
import 'ui/app_state.dart';

/// Game-level event instrumentation: counts events that reach the component
/// tree at all, so tests can tell "recognizer not attached" apart from
/// "routing to HUD children broken".
int _rawPointerDowns = 0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // In-memory save: store is never read from or written to (diskWrites=false).
  AppState.diskWrites = false;
  AppState.init(
    store: SaveStore(),
    save: SaveData(tutorialSeen: true),
  );

  final params = Uri.base.queryParameters;
  final levelId = params['level'] ?? 'w1_l1';
  final seed = int.tryParse(params['seed'] ?? '') ?? 42;
  // AKP-4a evidence: ?weapon=<catalog id> boots with that weapon owned +
  // equipped (harness-only; the in-memory save never persists).
  final weapon = params['weapon'];
  if (weapon != null && kWeapons.any((w) => w.id == weapon)) {
    AppState.save.ownedWeapons.add(weapon);
    AppState.save.equippedWeapon = weapon;
  }
  // AKP-4c evidence: ?apples=N pre-fills the pouch (harness-only) so the
  // held-throw arc preview can be exercised without hunting pickups.
  final apples = int.tryParse(params['apples'] ?? '') ?? 0;
  var applesApplied = false;

  final game = EmberGame(levelId: levelId, seedOverride: seed);

  // Telemetry bridge: browser tests poll window.__emberdelve.
  Timer.periodic(const Duration(milliseconds: 50), (_) {
    final obj = JSObject();
    var loaded = false;
    try {
      if (!applesApplied && apples > 0) {
        game.session.applesHeld = apples;
        applesApplied = true;
      }
      final body = game.session.player.body;
      obj.setProperty('x'.toJS, body.centerX.toJS);
      obj.setProperty('y'.toJS, body.centerY.toJS);
      obj.setProperty('hearts'.toJS, game.session.player.hearts.toJS);
      obj.setProperty('coins'.toJS, game.session.coinsCollected.toJS);
      obj.setProperty('touchLeft'.toJS, game.touchLeft.toJS);
      obj.setProperty('touchRight'.toJS, game.touchRight.toJS);
      obj.setProperty('paused'.toJS, game.paused.toJS);
      // Run/outcome state: lets a driver verify a FULL level clear instead of
      // just movement (the alpha.3 harness could only watch x/y).
      final s = game.session;
      obj.setProperty('level'.toJS, game.levelId.toJS);
      obj.setProperty('levelName'.toJS, s.level.name.toJS);
      obj.setProperty('time'.toJS, s.time.toJS);
      obj.setProperty('completed'.toJS, s.completed.toJS);
      obj.setProperty('failed'.toJS, s.failed.toJS);
      obj.setProperty('over'.toJS, s.over.toJS);
      obj.setProperty('apples'.toJS, s.applesHeld.toJS);
      obj.setProperty('feathers'.toJS, s.feathersCollected.toJS);
      obj.setProperty('kills'.toJS, s.kills.toJS);
      obj.setProperty('hitsTaken'.toJS, s.hitsTaken.toJS);
      obj.setProperty('secrets'.toJS, s.secretsFound.toJS);
      obj.setProperty('chestsOpened'.toJS,
          s.chests.where((c) => c.opened).length.toJS);
      obj.setProperty('chestTotal'.toJS, s.chests.length.toJS);
      obj.setProperty('enemiesAlive'.toJS,
          s.enemies.where((e) => e.alive).length.toJS);
      obj.setProperty('exitX'.toJS, s.exitX.toJS);
      obj.setProperty('exitY'.toJS, s.exitY.toJS);
      obj.setProperty('levelW'.toJS, (s.level.width * 16).toJS);
      obj.setProperty('levelH'.toJS, (s.level.height * 16).toJS);
      loaded = true;
    } catch (_) {
      // session not initialised yet (game still loading)
    }
    obj.setProperty('loaded'.toJS, loaded.toJS);
    obj.setProperty('rawPointerDowns'.toJS, _rawPointerDowns.toJS);
    globalContext.setProperty('__emberdelve'.toJS, obj);
  });

  runApp(MaterialApp(
    title: 'Emberwood (web test harness)',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent e) => _rawPointerDowns++,
        child: GameWidget(
        game: game,
        // Harness bug (found in the alpha.3 playtest): the game adds
        // 'results'/'fail'/'pause' overlays at level end. With no
        // overlayBuilderMap the widget threw "Null check operator used on a
        // null value" and the canvas went grey, so no automated run could
        // ever verify a level CLEAR. Minimal stand-ins keep the harness alive
        // (the real overlays live in ui/game_screen.dart).
        overlayBuilderMap: {
          EmberGame.overlayResults: (_, EmberGame g) =>
              const _HarnessBanner('LEVEL COMPLETE'),
          EmberGame.overlayFail: (_, EmberGame g) =>
              const _HarnessBanner('DEFEAT'),
          EmberGame.overlayPause: (_, EmberGame g) =>
              const _HarnessBanner('PAUSED'),
        },
      ),
      ),
    ),
  ));
}

/// Minimal overlay stand-in for the harness (see [GameWidget.overlayBuilderMap]).
class _HarnessBanner extends StatelessWidget {
  const _HarnessBanner(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: const Color(0xCC000000),
          child: Text(label,
              style: const TextStyle(color: Color(0xFFFFD37A), fontSize: 28)),
        ),
      );
}
