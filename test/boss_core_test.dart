// Grove Golem boss: phase thresholds, telegraphed attacks per phase,
// hazard damage windows, exit-door lock, and the victory burst.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/enemies/boss_core.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';

const dt = 1 / 120;

// A closed arena: player on the left, golem mid, door on the right.
const arena = '''
##############################
#............................#
#............................#
#............................#
#.P...........G............E.#
##############################
''';

LevelSession bossSession({int seed = 5}) =>
    LevelSession(LevelData.parse(arena), Loadout.starter(), seed: seed);

void step(LevelSession s, double seconds,
    [void Function(InputIntent)? config]) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    config?.call(intent);
    s.update(dt, intent);
    if (s.over) return;
  }
}

void main() {
  test('legend G spawns the golem with full hp; exit is locked', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    expect(boss.hp, GroveGolemCore.maxHp);
    expect(boss.phase, 1);
    expect(s.exitLocked, isTrue);
    expect(s.bossPresent, isTrue);
  });

  test('phase thresholds: 2/3 -> phase 2, 1/3 -> phase 3, with events', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    final phases = <int>[];
    void pump() {
      final intent = InputIntent()..clearEdges();
      s.update(dt, intent);
      for (final e in s.takeEvents()) {
        if (e.kind == SessionEventKind.bossPhase) phases.add(e.x.round());
      }
    }

    boss.hp = (GroveGolemCore.maxHp * 2 / 3).floor(); // 40 -> phase 2
    pump();
    expect(boss.phase, 2);
    boss.hp = (GroveGolemCore.maxHp / 3).floor(); // 20 -> phase 3
    pump();
    expect(boss.phase, 3);
    expect(phases, [2, 3]);
  });

  test('every attack is telegraphed before hazards exist', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    var sawTelegraph = false;
    var telegraphBeforeHazard = false;
    final intent = InputIntent();
    for (var i = 0; i < (6.0 / dt).round(); i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      if (boss.bossState == BossState.telegraph) sawTelegraph = true;
      if (boss.hazards.isNotEmpty) {
        telegraphBeforeHazard = sawTelegraph;
        break;
      }
    }
    expect(sawTelegraph, isTrue);
    expect(telegraphBeforeHazard, isTrue,
        reason: 'hazards must never appear before a telegraph');
  });

  test('phase 1 slam: shockwave travels along the ground and can hit', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    final hearts0 = s.player.hearts;
    var sawShockwave = false;
    var waveMoved = false;
    double? waveX0;
    final intent = InputIntent();
    for (var i = 0; i < (10.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      final waves = boss.hazards
          .where((h) => h.kind == BossHazardKind.shockwave)
          .toList();
      if (waves.isNotEmpty) {
        sawShockwave = true;
        waveX0 ??= waves.first.x;
        if ((waves.first.x - waveX0).abs() > 20) waveMoved = true;
      }
      if (s.player.hearts < hearts0) break;
    }
    expect(sawShockwave, isTrue);
    expect(waveMoved, isTrue);
    expect(s.player.hearts, lessThan(hearts0),
        reason: 'an idle player standing on the floor gets hit by the wave');
    expect(s.hitsTaken, greaterThanOrEqualTo(1));
  });

  test('phase 2 root spikes: harmless warning first, then harmful', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    boss.hp = 30; // phase 2
    var sawWarning = false;
    var sawHarmful = false;
    final intent = InputIntent();
    for (var i = 0; i < (20.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      for (final h in boss.hazards) {
        if (h.kind != BossHazardKind.rootSpike) continue;
        if (!h.harmful) sawWarning = true;
        if (h.harmful && sawWarning) sawHarmful = true;
      }
      if (sawHarmful) break;
    }
    expect(sawWarning, isTrue, reason: 'spikes must warn before erupting');
    expect(sawHarmful, isTrue);
  });

  test('phase 3 lobs rock arcs', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    boss.hp = 10; // phase 3
    var sawRock = false;
    final intent = InputIntent();
    for (var i = 0; i < (20.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      if (boss.hazards.any((h) => h.kind == BossHazardKind.rock)) {
        sawRock = true;
        break;
      }
    }
    expect(sawRock, isTrue);
  });

  test('door stays locked while the boss lives, opens on death with burst',
      () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    // Teleport the player into the door while the boss is alive: no finish.
    s.player.body.x = s.exitX - s.player.body.w / 2;
    s.player.body.y = s.exitY - s.player.body.h - 1;
    final intent = InputIntent()..clearEdges();
    s.update(dt, intent);
    expect(s.completed, isFalse, reason: 'exit locked during the fight');

    // Kill the boss outright.
    boss.hp = 1;
    boss.damage(1);
    expect(boss.alive, isFalse);
    // Session notices the death through melee normally; here we emulate the
    // burn/death path by invoking a frame — death via damage() outside a
    // swing still needs the door unlock check to pass:
    expect(s.exitLocked, isFalse);
    s.update(dt, intent..clearEdges());
    expect(s.completed, isTrue, reason: 'door usable once the boss is dead');
  });

  test('boss death via melee grants a big coin+feather burst', () {
    final s = bossSession();
    final boss = s.enemies.whereType<GroveGolemCore>().single;
    boss.hp = 1;
    // Walk up and land one hit.
    final coinsBefore = s.coins.length;
    final feathersBefore =
        s.pickups.where((p) => p.kind == SpawnKind.feather).length;
    final events = <SessionEventKind>[];
    final intent = InputIntent();
    for (var i = 0; i < (20.0 / dt).round() && boss.alive && !s.over; i++) {
      intent.clearEdges();
      intent.dirX = (boss.centerX - s.player.body.centerX) > 40 ? 1.0 : 0.0;
      if (i % 25 == 0) intent.attackPressed = true;
      s.update(dt, intent);
      events.addAll(s.takeEvents().map((e) => e.kind));
    }
    expect(boss.alive, isFalse, reason: 'player should land the last hit');
    expect(events, contains(SessionEventKind.bossDefeated));
    expect(s.coins.length - coinsBefore, greaterThanOrEqualTo(45));
    final feathersAfter =
        s.pickups.where((p) => p.kind == SpawnKind.feather).length;
    expect(feathersAfter - feathersBefore, 3);
    expect(s.exitLocked, isFalse);
  });
}
