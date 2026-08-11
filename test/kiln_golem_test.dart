// Kiln Golem (World 2 boss): a genuinely distinct moveset — mortar embers
// that ignite lingering fire patches, marching vent-flame walls, and a
// phase-3 volley — plus the shared boss contract (phases, telegraphs,
// exit-door lock, victory burst). Regression guard: until 2026-07-26 the
// "Kiln Golem" was a renamed GroveGolemCore (same fight as World 1).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/enemies/boss_core.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';

const dt = 1 / 120;

// A closed arena: player on the left, kiln golem mid, door on the right.
const arena = '''
##############################
#............................#
#............................#
#............................#
#.P...........M............E.#
##############################
''';

LevelSession bossSession({int seed = 5}) =>
    LevelSession(LevelData.parse(arena), Loadout.starter(), seed: seed);

const groveKinds = {
  BossHazardKind.shockwave,
  BossHazardKind.rootSpike,
  BossHazardKind.rock,
};

void main() {
  test('legend M spawns the kiln golem with full hp; exit is locked', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    expect(boss.hp, KilnGolemCore.maxHp);
    expect(boss.maxHpTotal, KilnGolemCore.maxHp,
        reason: 'HUD bar fraction keys off maxHpTotal');
    expect(boss.phase, 1);
    expect(s.exitLocked, isTrue);
    expect(s.bossPresent, isTrue);
    expect(s.boss, same(boss), reason: 'session boss getter is kind-agnostic');
  });

  test('phase thresholds: 2/3 -> phase 2, 1/3 -> phase 3, with events', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    final phases = <int>[];
    void pump() {
      final intent = InputIntent()..clearEdges();
      s.update(dt, intent);
      for (final e in s.takeEvents()) {
        if (e.kind == SessionEventKind.bossPhase) phases.add(e.x.round());
      }
    }

    boss.hp = (KilnGolemCore.maxHp * 2 / 3).floor(); // -> phase 2
    pump();
    expect(boss.phase, 2);
    boss.hp = (KilnGolemCore.maxHp / 3).floor(); // -> phase 3
    pump();
    expect(boss.phase, 3);
    expect(phases, [2, 3]);
  });

  test('every attack is telegraphed before hazards exist', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
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

  test('the kiln golem never borrows grove hazards in any phase', () {
    for (final hp in [KilnGolemCore.maxHp, 30, 10]) {
      final s = bossSession();
      final boss = s.enemies.whereType<KilnGolemCore>().single;
      boss.hp = hp;
      final intent = InputIntent();
      for (var i = 0; i < (25.0 / dt).round() && !s.over; i++) {
        intent.clearEdges();
        s.update(dt, intent);
        s.takeEvents();
        for (final h in boss.hazards) {
          expect(groveKinds.contains(h.kind), isFalse,
              reason: 'kiln golem at hp=$hp spawned grove hazard ${h.kind} '
                  '— the movesets must stay distinct');
        }
      }
    }
  });

  test('phase 1 mortar: embers arc, ignite fire patches, and threaten an '
      'idle player', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    final hearts0 = s.player.hearts;
    var sawBomb = false;
    var bombMoved = false;
    var sawPatch = false;
    double? bombY0;
    final intent = InputIntent();
    for (var i = 0; i < (25.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      for (final h in boss.hazards) {
        if (h.kind == BossHazardKind.emberBomb) {
          sawBomb = true;
          bombY0 ??= h.y;
          if ((h.y - bombY0).abs() > 10) bombMoved = true;
        }
        if (h.kind == BossHazardKind.firePatch) sawPatch = true;
      }
      if (sawPatch && s.player.hearts < hearts0) break;
    }
    expect(sawBomb, isTrue, reason: 'mortar embers must be lobbed');
    expect(bombMoved, isTrue, reason: 'embers must arc, not hang');
    expect(sawPatch, isTrue, reason: 'a landed ember must ignite the floor');
    expect(s.player.hearts, lessThan(hearts0),
        reason: 'an idle player standing on the floor gets punished');
    expect(s.hitsTaken, greaterThanOrEqualTo(1));
  });

  test('phase 2 vent wall: harmless warnings first, then eruptions that '
      'march away from the golem', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    boss.hp = 30; // phase 2
    var sawWarning = false;
    var sawHarmful = false;
    final pillarXs = <double>{};
    final intent = InputIntent();
    for (var i = 0; i < (25.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      for (final h in boss.hazards) {
        if (h.kind != BossHazardKind.flamePillar) continue;
        pillarXs.add(h.x);
        if (!h.harmful) sawWarning = true;
        if (h.harmful && sawWarning) sawHarmful = true;
      }
      if (sawHarmful && pillarXs.length >= 4) break;
    }
    expect(sawWarning, isTrue, reason: 'vents must warn before erupting');
    expect(sawHarmful, isTrue);
    expect(pillarXs.length, greaterThanOrEqualTo(4),
        reason: 'the wall is a marching line of pillars, not one column');
  });

  test('phase 3 volley lobs at least three embers per cast', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    boss.hp = 10; // phase 3
    var maxAirborne = 0;
    final intent = InputIntent();
    for (var i = 0; i < (30.0 / dt).round() && !s.over; i++) {
      intent.clearEdges();
      s.update(dt, intent);
      s.takeEvents();
      final n = boss.hazards
          .where((h) => h.kind == BossHazardKind.emberBomb)
          .length;
      if (n > maxAirborne) maxAirborne = n;
      if (maxAirborne >= 3) break;
    }
    expect(maxAirborne, greaterThanOrEqualTo(3));
  });

  test('door stays locked while the boss lives, opens on death with burst',
      () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    s.player.body.x = s.exitX - s.player.body.w / 2;
    s.player.body.y = s.exitY - s.player.body.h - 1;
    final intent = InputIntent()..clearEdges();
    s.update(dt, intent);
    expect(s.completed, isFalse, reason: 'exit locked during the fight');

    boss.hp = 1;
    boss.damage(1);
    expect(boss.alive, isFalse);
    expect(s.exitLocked, isFalse);
    s.update(dt, intent..clearEdges());
    expect(s.completed, isTrue, reason: 'door usable once the boss is dead');
  });

  test('boss death via melee grants the big coin+feather burst', () {
    final s = bossSession();
    final boss = s.enemies.whereType<KilnGolemCore>().single;
    boss.hp = 1;
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
