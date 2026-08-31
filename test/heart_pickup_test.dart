// Heart pickups (AKP-7a) — mid-run healing for the measured attrition wipes.
//
// Measured 2026-08-31 with the upgraded casual bot (held jumps, double-jump
// on stall, backtracking), 4 seeds, 300 s cap: w1_l5 wiped at 32-41% and
// w2_l4 at 73% on EVERY seed, because a checkpoint gap holds more than three
// hearts of unavoidable-for-a-casual damage and the game had zero mid-run
// healing (only the heal spell and the full-heal on respawn). The loop was
// always the same: 3 hits -> death -> respawn at the same campfire -> replay
// the identical pattern until the lives ran out. Hearts placed inside those
// stretches break the loop the way Apple Knight's food does.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';

const dt = 1 / 60;

LevelData parse(String s) => LevelData.parse(s);

const _testLevel = '''
meta: name=HeartTest
P....h....E
###########
''';

void main() {
  test("'h' parses as a heart spawn", () {
    final l = parse(_testLevel);
    final hearts = l.spawns.where((s) => s.kind == SpawnKind.heart).toList();
    expect(hearts, hasLength(1));
    expect(hearts.single.x, 5);
  });

  test('a hurt player walking over a heart heals 1 heart', () {
    final s = LevelSession(parse(_testLevel), Loadout.starter(), seed: 1);
    s.player.hearts = 1;
    final input = InputIntent()..dirX = 1;
    var t = 0.0;
    while (t < 5 && s.player.hearts == 1) {
      s.update(dt, input);
      t += dt;
    }
    expect(s.player.hearts, 2, reason: 'heart restores exactly 1 heart');
    expect(s.pickups.single.collected, isTrue);
  });

  test('at full health the heart stays put — come back for it hurt', () {
    final s = LevelSession(parse(_testLevel), Loadout.starter(), seed: 1);
    final input = InputIntent()..dirX = 1;
    var t = 0.0;
    // Walk the full runway at full health.
    while (t < 5 && s.player.body.centerX < 9 * 16) {
      s.update(dt, input);
      t += dt;
    }
    expect(s.pickups.single.collected, isFalse,
        reason: 'a heart must never be wasted on a full health bar');
    expect(s.player.hearts, s.player.maxHearts);
    // Get hurt, walk back over it: now it heals.
    s.player.hearts = 2;
    input.dirX = -1;
    t = 0.0;
    while (t < 5 && !s.pickups.single.collected) {
      s.update(dt, input);
      t += dt;
    }
    expect(s.pickups.single.collected, isTrue);
    expect(s.player.hearts, 3);
  });

  test('healing never exceeds max hearts', () {
    final s = LevelSession(parse(_testLevel), Loadout.starter(), seed: 1);
    s.player.hearts = s.player.maxHearts - 1;
    final input = InputIntent()..dirX = 1;
    var t = 0.0;
    while (t < 5 && !s.pickups.single.collected) {
      s.update(dt, input);
      t += dt;
    }
    expect(s.player.hearts, s.player.maxHearts);
  });

  test('collecting a heart emits heartPickup (sfx/fx hook)', () {
    final s = LevelSession(parse(_testLevel), Loadout.starter(), seed: 1);
    s.player.hearts = 1;
    final input = InputIntent()..dirX = 1;
    var t = 0.0, seen = false;
    while (t < 5 && !seen) {
      s.update(dt, input);
      seen = s
          .takeEvents()
          .any((e) => e.kind == SessionEventKind.heartPickup);
      t += dt;
    }
    expect(seen, isTrue);
  });

  // Design pin: the two levels the probe measured as guaranteed casual wipes
  // keep at least one heart inside their attrition stretch. If a level
  // rework removes them, this fails and the probe run must be repeated.
  for (final id in ['w1_l5', 'w2_l4']) {
    test('$id keeps mid-run healing in its attrition stretch', () {
      final l = LevelData.parse(
          File('assets/levels/$id.txt').readAsStringSync());
      final hearts = l.spawns.where((s) => s.kind == SpawnKind.heart);
      expect(hearts, isNotEmpty,
          reason: '$id wiped the casual bot on every seed without one');
    });
  }
}
