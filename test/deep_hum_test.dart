// test/deep_hum_test.dart — v0.23.0 "The Deep Hum": the map ambience bed
// deepens with descent. Two gameplay-owned pure pieces are pinned here, with
// no platform player involved (same split as the danger-bed rule):
//   * AudioService.mapAmbienceLevel — the depth -> relative-level curve.
//   * GameController.mapDepth — first layer 0.0 .. boss layer 1.0, read from
//     the sealed sim's map state.
import 'dart:io';

import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mapAmbienceLevel curve', () {
    test('endpoints: surface whisper, boss-layer hum', () {
      expect(AudioService.mapAmbienceLevel(0), closeTo(0.12, 1e-9));
      expect(AudioService.mapAmbienceLevel(1), closeTo(0.45, 1e-9));
    });

    test('monotonic in depth', () {
      var prev = -1.0;
      for (var i = 0; i <= 10; i++) {
        final v = AudioService.mapAmbienceLevel(i / 10);
        expect(v, greaterThan(prev));
        prev = v;
      }
    });

    test('out-of-range depths clamp instead of extrapolating', () {
      expect(AudioService.mapAmbienceLevel(-2), closeTo(0.12, 1e-9));
      expect(AudioService.mapAmbienceLevel(7), closeTo(0.45, 1e-9));
    });

    test('map bed stays under the fixed title bed at mid-depth', () {
      // Title/rest bed runs at 0.35 relative; the map bed should only pass
      // it in the deep third, so the map screen is not suddenly louder than
      // the title screen from layer 1.
      expect(AudioService.mapAmbienceLevel(0.5), lessThan(0.35));
    });
  });

  group('GameController.mapDepth', () {
    late Directory dir;
    late GameController c;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('ed_deep_hum');
      MetaStore.dirOverride = dir.path;
      c = GameController(saveDirOverride: dir.path);
      await c.boot();
    });

    tearDown(() {
      MetaStore.dirOverride = null;
      for (var i = 0; i < 10; i++) {
        try {
          dir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          sleep(const Duration(milliseconds: 50));
        }
      }
    });

    test('no run -> depth 0', () {
      expect(c.sim, isNull);
      expect(c.mapDepth, 0);
    });

    test('run start sits on the first layer at depth 0', () {
      c.startRun(seed: 20260723);
      expect(c.mapDepth, 0);
    });

    test('depth never decreases over a full winning run and ends at 1', () {
      // Drive the sealed sim with the autoplay bot exactly like playRun,
      // reading depth after every command — descent is forward-only, so the
      // ambience level must never step back down mid-run.
      final result = playRun(20260723);
      expect(result.sim.phase, 'run_won');
      // Replay: fresh sim, same seed, tracking depth via a controller-shaped
      // computation on live state.
      final sim = Sim(20260723);
      var prev = 0.0;
      var guard = 0;
      while (!sim.phase.startsWith('run_') && guard++ < 4000) {
        final cmd = botCmd(sim);
        if (cmd == null) break;
        sim.apply(cmd);
        final map = sim.state()['map'] as Map?;
        if (map == null) continue;
        final layers = map['layers'] as int;
        final node = (map['nodes'] as Map)['${map['position']}'] as Map;
        final depth = ((node['layer'] as int) - 1) / (layers - 1);
        expect(
          depth,
          greaterThanOrEqualTo(prev),
          reason: 'descent must be forward-only',
        );
        prev = depth;
      }
      expect(sim.phase, 'run_won');
      expect(prev, 1.0, reason: 'a won run ends on the boss layer');
    });
  });
}
