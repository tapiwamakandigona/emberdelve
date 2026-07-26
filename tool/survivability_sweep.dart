// tool/survivability_sweep.dart — the measurement behind every "is this level
// fair?" claim. Runs the casual bot (hold forward, jump when stalled, swing on
// a cadence, back off for a beat after taking a hit — the same script as
// test/fairness_test.dart) across every shipped level and prints, per level:
//
//   survived  seconds before the run ended (cap = the sample window)
//   reached   % of the level's width the player got to
//   deaths / hits / lives left
//
// This is a measurement tool, not a test: it never asserts. The assertions
// live in test/fairness_test.dart so CI stays fast.
//
// Run: flutter test tool/survivability_sweep.dart
// (a flutter-test harness rather than `dart run`, because the package pulls in
// Flutter transitively; it lives in tool/ so CI's `flutter test` never runs it)
//
// Window and level list come from the environment so no code edit is needed:
//   SWEEP_SECONDS=60 SWEEP_LEVELS=w2_l1,w2_l2 flutter test tool/survivability_sweep.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/difficulty.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 60;
const allLevels = [
  'w1_l1', 'w1_l2', 'w1_l3', 'w1_l4', 'w1_l5', 'w1_boss',
  'w2_l1', 'w2_l2', 'w2_l3', 'w2_l4', 'w2_l5', 'w2_boss',
];

class Run {
  final double seconds;
  final double reachedPct;
  final int deaths;
  final int hits;
  final int lives;
  final bool failed;
  final bool completed;
  Run(this.seconds, this.reachedPct, this.deaths, this.hits, this.lives,
      this.failed, this.completed);
}

Run playCasual(String id, {double window = 180, int seed = 7}) {
  final level = LevelData.parse(
      File('assets/levels/$id.txt').readAsStringSync());
  final s = LevelSession(level, Loadout.starter(),
      seed: seed, difficulty: Difficulty.medium);
  final input = InputIntent();
  var t = 0.0, stall = 0.0, attack = 0.0, backOff = 0.0;
  var lastX = s.player.body.x, hits = 0;
  while (t < window && !s.over) {
    if (s.hitsTaken != hits) {
      hits = s.hitsTaken;
      backOff = 0.7;
    }
    backOff = backOff > 0 ? backOff - dt : 0;
    input
      ..dirX = backOff > 0 ? 0 : 1
      ..jumpPressed = false
      ..jumpHeld = false
      ..attackPressed = false;
    if ((s.player.body.x - lastX).abs() < 0.3) {
      stall += dt;
    } else {
      stall = 0;
    }
    lastX = s.player.body.x;
    if (stall > 0.2) {
      input
        ..jumpPressed = true
        ..jumpHeld = true;
      stall = 0;
    }
    attack += dt;
    if (attack > 0.5) {
      attack = 0;
      input.attackPressed = true;
    }
    s.update(dt, input);
    t += dt;
  }
  final pct = 100 * s.player.body.centerX / (s.level.width * kTileSize);
  return Run(t, pct, s.deaths, s.hitsTaken, s.lives, s.failed, s.completed);
}

void main() {
  test('casual-bot survivability sweep', () {
    final env = Platform.environment;
    final window = double.parse(env['SWEEP_SECONDS'] ?? '180');
    final levels = (env['SWEEP_LEVELS']?.split(',') ?? allLevels)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    stdout.writeln('casual-bot sweep, ${window.round()}s window\n');
    stdout.writeln('level     survived  reached  deaths  hits  lives  outcome');
    for (final id in levels) {
      final r = playCasual(id, window: window);
      final outcome = r.completed
          ? 'cleared'
          : r.failed
              ? 'WIPED'
              : 'alive';
      stdout.writeln('${id.padRight(9)} '
          '${r.seconds.toStringAsFixed(1).padLeft(7)}s '
          '${r.reachedPct.round().toString().padLeft(6)}% '
          '${r.deaths.toString().padLeft(7)} '
          '${r.hits.toString().padLeft(5)} '
          '${r.lives.toString().padLeft(6)}  $outcome');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
