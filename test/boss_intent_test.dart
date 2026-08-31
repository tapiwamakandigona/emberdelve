// boss_intent_test — permanent design gate: each boss's COACHED strategy
// must beat it with the starter loadout on every seed (2026-08-31 review).
//
// The casual masher probe wiping on bosses is BY DESIGN (fairness_test.dart:
// "bosses are a skill check"). What must never regress is the coached route:
//   Grove Golem (w1): its sign says "watch its wind-up - then strike" —
//     approach in idle/recover, strike, retreat during telegraph/attack,
//     jump shockwaves and falling rocks, sidestep root marks.
//   Kiln Golem (w2): caged in its kiln pen — ground melee CANNOT reach it
//     (measured: every ground bot deals 0/60). The coached route is the
//     pillar-top perch (the apples up there are the breadcrumb): jump the
//     fire moat, double-jump to the pillar crown, poke its head, sidestep
//     mortar embers. If a level edit breaks the perch reach or the moat
//     jump, this gate goes red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/difficulty.dart';
import 'package:emberwood/game/enemies/boss_core.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';

const dt = 1 / 60;
const seeds = [7, 13, 42, 99];

LevelData load(String id) =>
    LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());

void main() {
  for (final target in const ['w1_boss', 'w2_boss']) {
    test(
      'coached strategy beats $target',
      () {
        for (final seed in seeds) {
          final s = LevelSession(
            load(target),
            Loadout.starter(),
            seed: seed,
            difficulty: Difficulty.medium,
          );
          final input = InputIntent();
          var t = 0.0, attack = 0.0, hits = 0;
          var jumpHold = 0.0;
          final hitLog = <String>[];
          while (t < 300 && !s.over) {
            final boss = s.enemies
                .whereType<BossCore>()
                .where((e) => e.alive)
                .toList();
            if (s.hitsTaken != hits) {
              hits = s.hitsTaken;
              hitLog.add(
                't=${t.toStringAsFixed(1)} hearts=${s.player.hearts} '
                'bossState=${boss.isEmpty ? "dead" : boss.first.bossState} '
                'bossHp=${boss.isEmpty ? 0 : boss.first.hp}',
              );
            }
            input
              ..dirX = 0
              ..jumpPressed = false
              ..jumpHeld = jumpHold > 0
              ..attackPressed = false;
            if (jumpHold > 0) jumpHold -= dt;
            if (boss.isEmpty) {
              // Boss dead: run right to the exit; look where you walk — jump
              // fire moats proactively, double-jump climbs on stall.
              input.dirX = 1;
              final px = s.player.body.centerX;
              final footRow = (s.player.body.bottom / kTileSize).floor();
              var fireAhead = false;
              for (var k = 1; k <= 2; k++) {
                final cx = (px / kTileSize).floor() + k;
                for (var r = footRow; r <= footRow + 1; r++) {
                  if (r < 0 || r >= s.grid.length) continue;
                  if (cx < 0 || cx >= s.grid[r].length) continue;
                  final tk = s.grid[r][cx];
                  if (tk == TileKind.fire || tk == TileKind.spikes) {
                    fireAhead = true;
                  }
                }
              }
              if (s.player.body.onGround &&
                  (fireAhead || s.player.body.vx.abs() < 5)) {
                input
                  ..jumpPressed = true
                  ..jumpHeld = true;
                jumpHold = 0.35;
              } else if (!s.player.body.onGround &&
                  s.player.body.vy > -40 &&
                  jumpHold <= 0) {
                input.jumpPressed = true; // double jump to finish climbs
                jumpHold = 0.3;
              }
            } else {
              final b = boss.first;
              final px = s.player.body.centerX;
              final dx = b.centerX - px;
              final dist = dx.abs();
              final danger =
                  b.bossState == BossState.telegraph ||
                  b.bossState == BossState.attack;
              // Hazard reads: shockwaves/pillars/rocks to hop, embers to sidestep.
              var hazJump = false;
              var sidestep =
                  0; // -1/1: move away from a predicted ember landing
              for (final h in b.hazards) {
                if (!h.active) continue;
                final hd = (h.x - px).abs();
                if (hd < 44 &&
                    (h.kind == BossHazardKind.shockwave ||
                        (h.kind == BossHazardKind.flamePillar &&
                            h.warning < 0.35) ||
                        (h.kind == BossHazardKind.rock &&
                            h.y > s.player.body.top))) {
                  hazJump = true;
                }
                if (h.kind == BossHazardKind.firePatch && hd < 26) {
                  sidestep = h.x > px ? -1 : 1;
                }
                if (h.kind == BossHazardKind.emberBomb && h.vy > -60) {
                  // Falling ember: project its landing x, step out from under it.
                  final landX = h.x + h.vx * 0.35;
                  if ((landX - px).abs() < 30) sidestep = landX > px ? -1 : 1;
                }
              }
              // Caged boss (Kiln): it cannot leave its pen — the level's own
              // breadcrumbs (apples on the pillar tops) coach a perch fight.
              final caged = b is KilnGolemCore;
              if (caged) {
                const perchX = 424.0; // right edge of the left pillar top
                final onPerch =
                    s.player.body.bottom <= 209 && px > 384 && px < 434;
                if (!onPerch) {
                  // Navigate: run right, jump the fire moat, double-jump to top.
                  input.dirX = px < perchX ? 1 : -1;
                  if (s.player.body.onGround && px > 290 && px < 384) {
                    input
                      ..jumpPressed = true
                      ..jumpHeld = true;
                    jumpHold = 0.35;
                  } else if (!s.player.body.onGround &&
                      s.player.body.vy > -40 &&
                      px < 410 &&
                      jumpHold <= 0) {
                    input.jumpPressed = true; // double jump onto the pillar top
                    jumpHold = 0.3;
                  }
                } else {
                  // Perched: poke the head, sidestep ember landings and patches.
                  if (sidestep != 0) {
                    input.dirX = px < 396 ? 1.0 : sidestep.toDouble();
                  } else if (px < perchX - 3) {
                    input.dirX = 1;
                  } else if (px > perchX + 3) {
                    input.dirX = -1;
                  }
                  attack += dt;
                  if (attack > 0.3 && (b.centerX - px).abs() < 56) {
                    attack = 0;
                    input.attackPressed = true;
                  }
                }
                s.update(dt, input);
                s.takeEvents();
                t += dt;
                continue;
              }

              if (sidestep != 0) {
                input.dirX = sidestep.toDouble();
              } else if (danger && dist < 90) {
                // Mobile boss winding up: respect it, retreat to range.
                input.dirX = dx > 0 ? -1 : 1;
              } else {
                // Window open: close to the strike band.
                if (dist > 40) {
                  input.dirX = dx > 0 ? 1 : -1;
                } else if (dist < 30 && s.player.body.centerY > b.body.top) {
                  input.dirX = dx > 0 ? -1 : 1; // never share ground with it
                }
                attack += dt;
                if (dist < 52 && attack > 0.3) {
                  attack = 0;
                  input.attackPressed = true;
                }
              }
              // Climb: trying to move but pinned against terrain -> jump.
              if (input.dirX != 0 &&
                  s.player.body.vx.abs() < 8 &&
                  s.player.body.onGround) {
                input
                  ..jumpPressed = true
                  ..jumpHeld = true;
                jumpHold = 0.3;
              }
              if (hazJump && s.player.body.onGround) {
                input
                  ..jumpPressed = true
                  ..jumpHeld = true;
                jumpHold = 0.3;
              }
            }
            s.update(dt, input);
            s.takeEvents();
            t += dt;
          }
          final bossLeft = s.enemies.whereType<BossCore>().where(
            (e) => e.alive,
          );
          // ignore: avoid_print
          print(
            '[$target seed=$seed] '
            '${s.completed
                ? "COMPLETED"
                : s.failed
                ? "WIPED"
                : "TIMEOUT"} '
            't=${t.toStringAsFixed(0)}s deaths=${s.deaths} hits=${s.hitsTaken} '
            'bossHp=${bossLeft.isEmpty ? 0 : bossLeft.first.hp}/60',
          );
          for (final h in hitLog) {
            // ignore: avoid_print
            print('   hit $h');
          }
          expect(
            s.completed,
            isTrue,
            reason:
                '$target seed=$seed: the coached strategy must finish the '
                'level (got deaths=${s.deaths}, hits=${s.hitsTaken}, '
                't=${t.toStringAsFixed(0)}s)',
          );
          expect(
            s.deaths,
            lessThanOrEqualTo(2),
            reason:
                '$target seed=$seed: the coached strategy should win with '
                'a life to spare',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}
