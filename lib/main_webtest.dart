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

  final game = EmberGame(levelId: levelId, seedOverride: seed);

  // Telemetry bridge: browser tests poll window.__emberdelve.
  Timer.periodic(const Duration(milliseconds: 50), (_) {
    final obj = JSObject();
    var loaded = false;
    try {
      final body = game.session.player.body;
      obj.setProperty('x'.toJS, body.centerX.toJS);
      obj.setProperty('y'.toJS, body.centerY.toJS);
      obj.setProperty('hearts'.toJS, game.session.player.hearts.toJS);
      obj.setProperty('coins'.toJS, game.session.coinsCollected.toJS);
      obj.setProperty('touchLeft'.toJS, game.touchLeft.toJS);
      obj.setProperty('touchRight'.toJS, game.touchRight.toJS);
      obj.setProperty('paused'.toJS, game.paused.toJS);
      loaded = true;
    } catch (_) {
      // session not initialised yet (game still loading)
    }
    obj.setProperty('loaded'.toJS, loaded.toJS);
    obj.setProperty('rawPointerDowns'.toJS, _rawPointerDowns.toJS);
    globalContext.setProperty('__emberdelve'.toJS, obj);
  });

  runApp(MaterialApp(
    title: 'Emberdelve (web test harness)',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent e) => _rawPointerDowns++,
        child: GameWidget(game: game),
      ),
    ),
  ));
}
