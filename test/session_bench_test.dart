// Headless CPU benchmark for the sim hot path (P-M7 evidence).
//
// Measures LevelSession.update wall time while a scripted door-seeking bot
// (same driving logic as world1_levels_test.dart) plays w1_l5 (densest
// level) and w1_boss (all boss phases). This is the honest half of the
// 16 ms/frame budget we CAN measure without a device: pure-Dart sim cost on
// the UI thread. Raster/build cost still requires a device profile
// (docs/perf.md §2).
//
// The assertions are regression guards, not the real target: the sim should
// be 10-100x under these bounds. If this test ever fails, the hot path
// gained something expensive — find it before shipping.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';

class BenchStats {
  BenchStats(this.samplesUs);
  final List<int> samplesUs;

  double get avg =>
      samplesUs.reduce((a, b) => a + b) / samplesUs.length;
  int at(double q) {
    final sorted = [...samplesUs]..sort();
    return sorted[(sorted.length * q).floor().clamp(0, sorted.length - 1)];
  }

  @override
  String toString() =>
      'n=${samplesUs.length} avg=${avg.toStringAsFixed(1)}us '
      'p50=${at(.5)}us p95=${at(.95)}us p99=${at(.99)}us max=${at(1)}us';
}

/// Drive [id] with the door-seeking bot for up to [frames], timing each
/// session.update. First [warmup] frames are excluded (JIT warmup).
BenchStats bench(String id, {int frames = 60 * 90, int warmup = 240}) {
  final samples = <int>[];
  // A fast bot clear yields few samples; repeat runs until we have enough
  // for stable percentiles.
  for (var run = 0; samples.length < 2000 && run < 5; run++) {
    _drive(id, frames: frames, warmup: run == 0 ? warmup : 0, into: samples);
  }
  return BenchStats(samples);
}

void _drive(String id,
    {required int frames, required int warmup, required List<int> into}) {
  final l = LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());
  final s = LevelSession(l, Loadout.starter(), seed: 11);
  const dt = 1 / 60;
  final intent = InputIntent();
  var airJumped = false;
  final sw = Stopwatch();
  bool solidish(TileKind t) =>
      t == TileKind.solid || t == TileKind.platform || t == TileKind.crackedWall;
  for (var i = 0; i < frames; i++) {
    final b = s.player.body;
    final dir = s.exitX >= b.centerX ? 1.0 : -1.0;
    intent
      ..dirX = dir
      ..down = false
      ..jumpHeld = true;
    intent.clearEdges();
    s.player.hearts = 3; // god mode: cost, not skill, is under test
    if (b.onGround) {
      airJumped = false;
      final tx = dir > 0
          ? ((b.right + 6) / kTileSize).floor()
          : ((b.left - 6) / kTileSize).floor();
      final footTy = ((b.bottom + 1) / kTileSize).floor();
      final gapAhead = !solidish(s.tileAt(tx, footTy)) &&
          !solidish(s.tileAt(tx, footTy + 1));
      final wallAhead =
          solidish(s.tileAt(tx, ((b.top + 2) / kTileSize).floor())) ||
              solidish(s.tileAt(tx, ((b.bottom - 2) / kTileSize).floor()));
      if (gapAhead || wallAhead) intent.jumpPressed = true;
    } else if (b.vy > 30 && !airJumped) {
      intent.jumpPressed = true;
      airJumped = true;
    }
    if (i % 12 == 0) intent.attackPressed = true;
    sw
      ..reset()
      ..start();
    s.update(dt, intent);
    sw.stop();
    if (i >= warmup) into.add(sw.elapsedMicroseconds);
    // Drain event queues like the render layer would (they grow otherwise).
    s.takeEvents();
    s.takePlayerEvents();
    if (s.completed || s.failed) break;
  }
}

void main() {
  test('session update stays far under frame budget (w1_l5, w1_boss)', () {
    for (final id in ['w1_l5', 'w1_boss']) {
      final stats = bench(id);
      // ignore: avoid_print
      print('bench $id: $stats');
      expect(stats.samplesUs.length, greaterThan(1000),
          reason: '$id: bot run too short to be meaningful');
      // Generous regression bounds — sim should be microseconds, budget is
      // 16000us for the WHOLE frame. Fail = something expensive landed.
      expect(stats.avg, lessThan(2000), reason: '$id avg blew the bound');
      expect(stats.at(.99), lessThan(8000), reason: '$id p99 blew the bound');
    }
  });
}
