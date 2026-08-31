// wipe_probe_test.dart — the difficulty probe, committed so it stops
// drifting (it was rebuilt from notes twice and the two bots disagreed).
// Skipped in CI; run manually:
//   flutter test --run-skipped --dart-define=LVL=w1_l5 test/wipe_probe_test.dart
//
// Upgraded casual bot: held jumps 0.3s, double-jump on stall, 1.2s backtrack
// after 4s pinned at one column, 0.5s attack cadence, 0.7s back-off on hit.
// 300s cap, seeds 7/13/42/99, per-column stall + hit attribution.
@Skip('manual difficulty probe — run with --run-skipped')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/difficulty.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';

const dt = 1 / 60;
const seeds = [7, 13, 42, 99];
const target = String.fromEnvironment('LVL', defaultValue: 'w1_l5');

LevelData load(String id) =>
    LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());

void main() {
  test('wipe probe $target', () {
    for (final seed in seeds) {
      final s = LevelSession(load(target), Loadout.starter(),
          seed: seed, difficulty: Difficulty.medium);
      final input = InputIntent();
      var t = 0.0, stall = 0.0, lastX = s.player.body.x;
      var attack = 0.0, backOff = 0.0, hits = 0;
      var jumpHold = 0.0, pinned = 0.0, backtrack = 0.0;
      var pinnedCol = -1;
      final stallByCol = <int, double>{};
      final hitLog = <String>[];
      while (t < 300 && !s.over) {
        if (s.hitsTaken != hits) {
          hits = s.hitsTaken;
          backOff = 0.7;
          final col = s.player.body.centerX ~/ kTileSize;
          final near = s.enemies.where((e) => e.alive).toList()
            ..sort((a, b) => (a.body.centerX - s.player.body.centerX)
                .abs()
                .compareTo((b.body.centerX - s.player.body.centerX).abs()));
          final who = near.isEmpty
              ? 'hazard'
              : '${near.first.runtimeType}@${near.first.body.centerX ~/ kTileSize}';
          hitLog.add('t=${t.toStringAsFixed(1)} col=$col by=$who '
              'hearts=${s.player.hearts}');
        }
        backOff = backOff > 0 ? backOff - dt : 0;
        final col = s.player.body.centerX ~/ kTileSize;
        if ((s.player.body.x - lastX).abs() < 0.3) {
          stall += dt;
          pinned += dt;
          stallByCol[col] = (stallByCol[col] ?? 0) + dt;
        } else {
          stall = 0;
          if (col != pinnedCol) {
            pinned = 0;
            pinnedCol = col;
          }
        }
        lastX = s.player.body.x;
        if (pinned > 4.0) {
          backtrack = 1.2;
          pinned = 0;
        }
        backtrack = backtrack > 0 ? backtrack - dt : 0;
        input
          ..dirX = backOff > 0 ? 0 : (backtrack > 0 ? -1 : 1)
          ..jumpPressed = false
          ..jumpHeld = false
          ..attackPressed = false;
        if (jumpHold > 0) {
          jumpHold -= dt;
          input.jumpHeld = true;
        }
        if (stall > 0.2) {
          input
            ..jumpPressed = true
            ..jumpHeld = true;
          jumpHold = jumpHold > 0 ? 0 : 0.3; // second press = double jump
          stall = 0;
        }
        attack += dt;
        if (attack > 0.5) {
          attack = 0;
          input.attackPressed = true;
        }
        s.update(dt, input);
        s.takeEvents();
        t += dt;
      }
      final pct =
          (100 * s.player.body.centerX / (s.level.width * kTileSize)).round();
      final topStalls = (stallByCol.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(3)
          .map((e) => 'col${e.key}:${e.value.toStringAsFixed(0)}s')
          .join(' ');
      // ignore: avoid_print
      print('[$target seed=$seed] '
          '${s.completed ? "COMPLETED" : s.failed ? "WIPED" : "TIMEOUT"} '
          't=${t.toStringAsFixed(0)}s pct=$pct deaths=${s.deaths} '
          'hits=${s.hitsTaken} | stalls: $topStalls');
      for (final h in hitLog) {
        // ignore: avoid_print
        print('   hit $h');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
