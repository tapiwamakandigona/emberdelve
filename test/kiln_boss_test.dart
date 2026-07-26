// Kiln Golem (World 2 boss): its own moveset, not a re-tinted Grove Golem.
// Pins the fight's contract — every attack telegraphs before it can hurt you,
// each attack asks a different question (jump / move / bait), the charge leaves
// a punish window, and magma pools only appear in the enrage phase.
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/enemies/boss_core.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 120;

// A closed kiln arena: player left, golem mid, locked door right.
const arena = '''
##################################
#................................#
#................................#
#................................#
#.P.............Q..............E.#
##################################
''';

LevelSession kilnSession({int seed = 5}) =>
    LevelSession(LevelData.parse(arena), Loadout.starter(), seed: seed);

KilnGolemCore bossOf(LevelSession s) =>
    s.enemies.whereType<KilnGolemCore>().single;

/// Advance the session with no input (the player just stands there).
void step(LevelSession s, double seconds) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    s.update(dt, intent);
    if (s.over) return;
  }
}

/// Run until [want] has been executed at least once, collecting the hazards it
/// spawns. Returns null if it never came up.
List<BossHazard>? hazardsFrom(LevelSession s, BossAttack want,
    {double timeout = 30}) {
  final boss = bossOf(s);
  final intent = InputIntent();
  var attacking = false;
  for (var i = 0; i < (timeout / dt).round(); i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    // The player is immortal for this probe: we are measuring the boss, and a
    // dead player would end the session early.
    s.player.iFrames = 5;
    s.update(dt, intent);
    if (boss.bossState == BossState.attack && boss.pendingAttack == want) {
      attacking = true;
    }
    if (attacking && boss.hazards.isNotEmpty) {
      return List.of(boss.hazards);
    }
    if (attacking && want == BossAttack.charge) return const [];
  }
  return null;
}

void main() {
  test('legend Q spawns the Kiln Golem with its own hp; exit locked', () {
    final s = kilnSession();
    final boss = bossOf(s);
    expect(boss.hp, KilnGolemCore.maxHp);
    expect(KilnGolemCore.maxHp, isNot(GroveGolemCore.maxHp),
        reason: 'it is a different fight, not a re-skin');
    expect(s.enemies.whereType<GroveGolemCore>(), isEmpty);
    expect(boss.phase, 1);
    expect(s.exitLocked, isTrue);
    expect(s.bossPresent, isTrue);
    // The HUD bar reads the boss's own max, not a hard-coded Grove Golem one.
    expect(s.boss, same(boss));
    expect(s.boss!.maxHpValue, KilnGolemCore.maxHp);
  });

  test('phase thresholds at 2/3 and 1/3 hp, and the enrage is phase 3', () {
    final s = kilnSession();
    final boss = bossOf(s);
    expect(boss.phase, 1);
    boss.hp = (KilnGolemCore.maxHp * 2 / 3).floor();
    expect(boss.phase, 2);
    boss.hp = (KilnGolemCore.maxHp / 3).floor();
    expect(boss.phase, 3);
  });

  test('never harms anything before it telegraphs', () {
    final s = kilnSession();
    final boss = bossOf(s);
    final intent = InputIntent();
    var sawTelegraph = false;
    for (var i = 0; i < (6 / dt).round(); i++) {
      intent.clearEdges();
      s.player.iFrames = 5;
      s.update(dt, intent);
      if (boss.bossState == BossState.telegraph) sawTelegraph = true;
      if (boss.hazards.any((h) => h.harmful)) {
        expect(sawTelegraph, isTrue,
            reason: 'a harmful hazard existed before any wind-up');
        break;
      }
    }
    expect(sawTelegraph, isTrue, reason: 'the boss never wound up at all');
  });

  group('moveset', () {
    test('heat wave: one floor-level wall that travels and is jumpable', () {
      final s = kilnSession();
      final hz = hazardsFrom(s, BossAttack.heatWave);
      expect(hz, isNotNull);
      final wave = hz!.where((h) => h.kind == BossHazardKind.heatWave).toList();
      expect(wave, isNotEmpty);
      final w = wave.first;
      expect(w.vx.abs(), greaterThan(0), reason: 'a wall that stands still is '
          'not a wave');
      // Sits on the floor and is low enough to clear with a normal jump
      // (kJumpSpeed clears ~2.3 tiles) but too tall to walk or roll through.
      final r = w.rect;
      expect(r.h, greaterThan(kTileSize));
      expect(r.h, lessThan(kTileSize * 2));
      expect(r.y + r.h, closeTo(w.y, 0.01));
    });

    test('heat wave dies on the arena wall instead of living forever', () {
      final s = kilnSession();
      final boss = bossOf(s);
      final hz = hazardsFrom(s, BossAttack.heatWave);
      expect(hz, isNotNull);
      var alive = true;
      for (var i = 0; i < (6 / dt).round() && alive; i++) {
        s.player.iFrames = 5;
        s.update(dt, InputIntent()..clearEdges());
        alive = boss.hazards.any((h) => h.kind == BossHazardKind.heatWave);
      }
      expect(alive, isFalse);
    });

    test('geyser cascade: several vents, marked before eruption, in sequence',
        () {
      final s = kilnSession();
      final hz = hazardsFrom(s, BossAttack.geyserCascade);
      expect(hz, isNotNull);
      final vents =
          hz!.where((h) => h.kind == BossHazardKind.geyser).toList();
      expect(vents.length, greaterThanOrEqualTo(4),
          reason: 'a cascade is more than one dodge');
      // Every vent starts as a harmless mark...
      expect(vents.every((v) => v.warning > 0), isTrue);
      expect(vents.every((v) => !v.harmful), isTrue);
      // ...and they do not all erupt at once: the warnings are staggered.
      final warns = vents.map((v) => v.warning).toSet();
      expect(warns.length, vents.length);
      // ...marching away from the golem, not stacked on one column.
      final xs = vents.map((v) => v.x).toList();
      expect(xs.toSet().length, xs.length);
    });

    test('charge: the body commits, then leaves a long punish window', () {
      final s = kilnSession();
      final boss = bossOf(s);
      boss.hp = (KilnGolemCore.maxHp * 2 / 3).floor(); // phase 2 unlocks it
      final intent = InputIntent();
      var sawCharging = false;
      var chargeDistance = 0.0;
      var recoverSeconds = 0.0;
      var startX = boss.centerX;
      for (var i = 0; i < (40 / dt).round(); i++) {
        intent.clearEdges();
        s.player.iFrames = 5;
        s.update(dt, intent);
        if (boss.charging) {
          if (!sawCharging) startX = boss.centerX;
          sawCharging = true;
          chargeDistance = (boss.centerX - startX).abs();
        }
        if (sawCharging && !boss.charging) {
          if (boss.bossState == BossState.recover) {
            recoverSeconds += dt;
          } else if (recoverSeconds > 0) {
            break;
          }
        }
      }
      expect(sawCharging, isTrue, reason: 'phase 2 never charged in 40s');
      expect(chargeDistance, greaterThan(kTileSize * 2),
          reason: 'a charge has to actually cross ground');
      expect(recoverSeconds, greaterThan(0.5),
          reason: 'the charge must leave a real opening to punish');
    });

    test('magma bombs land as lingering pools, and only in the enrage', () {
      final s = kilnSession();
      final boss = bossOf(s);
      // Phase 1/2 must never produce a pool.
      var seenEarly = false;
      for (var i = 0; i < (20 / dt).round(); i++) {
        s.player.iFrames = 5;
        s.update(dt, InputIntent()..clearEdges());
        if (boss.hazards.any((h) =>
            h.kind == BossHazardKind.magmaPool ||
            h.kind == BossHazardKind.magmaBomb)) {
          seenEarly = true;
          break;
        }
      }
      expect(seenEarly, isFalse, reason: 'bombs are a phase-3 escalation');

      boss.hp = 6; // deep into the enrage
      var sawBomb = false, sawPool = false;
      for (var i = 0; i < (40 / dt).round(); i++) {
        s.player.iFrames = 5;
        s.update(dt, InputIntent()..clearEdges());
        for (final h in boss.hazards) {
          if (h.kind == BossHazardKind.magmaBomb) sawBomb = true;
          if (h.kind == BossHazardKind.magmaPool) sawPool = true;
        }
        if (sawPool) break;
      }
      expect(sawBomb, isTrue, reason: 'no bomb was ever lobbed in the enrage');
      expect(sawPool, isTrue, reason: 'a bomb must leave burning floor');
    });

    test('pools expire, so the arena never becomes unplayable', () {
      final s = kilnSession();
      final boss = bossOf(s);
      boss.hp = 6;
      var sawPool = false;
      for (var i = 0; i < (60 / dt).round(); i++) {
        s.player.iFrames = 5;
        s.update(dt, InputIntent()..clearEdges());
        final pools =
            boss.hazards.where((h) => h.kind == BossHazardKind.magmaPool);
        if (pools.isNotEmpty) sawPool = true;
        // Burning floor must never accumulate past a handful of patches.
        expect(pools.length, lessThanOrEqualTo(6));
      }
      expect(sawPool, isTrue);
    });
  });

  test('hazards only hurt while harmful, and the door opens on the kill', () {
    final s = kilnSession();
    final boss = bossOf(s);
    // A marked-but-not-erupted vent right under the player must not hit.
    boss.hazards.add(BossHazard(BossHazardKind.geyser, s.player.body.centerX,
        s.player.body.bottom,
        warning: 1.0, life: 0.65));
    expect(boss.hazardHits(s.player.body), isFalse);
    boss.hazards.first.warning = 0;
    expect(boss.hazardHits(s.player.body), isTrue);

    boss.hazards.clear();
    boss.damage(KilnGolemCore.maxHp);
    expect(boss.alive, isFalse);
    step(s, 0.2);
    expect(s.exitLocked, isFalse, reason: 'killing the boss unlocks the door');
  });

  test('the Grove Golem keeps its own moveset (no cross-contamination)', () {
    final s = LevelSession(
        LevelData.parse(arena.replaceFirst('Q', 'G')), Loadout.starter(),
        seed: 5);
    final grove = s.enemies.whereType<GroveGolemCore>().single;
    for (var i = 0; i < (20 / dt).round(); i++) {
      s.player.iFrames = 5;
      s.update(dt, InputIntent()..clearEdges());
      for (final h in grove.hazards) {
        expect(
            h.kind,
            isIn(const [
              BossHazardKind.shockwave,
              BossHazardKind.rootSpike,
              BossHazardKind.rock,
            ]),
            reason: 'World 1 must not inherit kiln hazards');
      }
    }
  });
}
