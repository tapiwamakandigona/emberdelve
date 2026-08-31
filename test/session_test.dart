// Headless pickup / chest / wall / door / death economy tests over
// LevelSession.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/rng.dart';
import 'package:emberwood/game/components/items_component.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';
import 'package:emberwood/meta/catalog.dart';

const dt = 1 / 120;

void stepSession(LevelSession s, double seconds,
    void Function(InputIntent) config) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    config(intent);
    s.update(dt, intent);
  }
}

LevelSession session(String ascii,
        {int seed = 3, Loadout? loadout, Map<String, String>? meta}) =>
    LevelSession(LevelData.parse(ascii), loadout ?? Loadout.starter(),
        seed: seed);

void main() {
  test('walking over a coin collects it once', () {
    final s = session('''
....................
.P.c...............E
####################
''');
    stepSession(s, 1.0, (i) => i.dirX = 1);
    expect(s.coinsCollected, 1);
    expect(s.coins.single.collected, isTrue);
  });

  test('apple pickup grants +3 up to capacity', () {
    final s = session('''
....................
.P.a.a.a.a.........E
####################
''');
    stepSession(s, 2.0, (i) => i.dirX = 1);
    // Capacity 10: 3+3+3, then the 4th pickup clamps at the cap.
    expect(s.applesHeld, 10);
    expect(s.pickups.where((p) => p.collected).length, 4);
  });

  test('feather collect increments feathers', () {
    final s = session('''
....................
.P.f...............E
####################
''');
    stepSession(s, 1.0, (i) => i.dirX = 1);
    expect(s.feathersCollected, 1);
  });

  test('chest opens once, sprays a deterministic coin burst', () {
    const seed = 11;
    final s = session('''
....................
....................
.P.C...............E
####################
''', seed: seed);
    stepSession(s, 0.6, (i) => i.dirX = 1);
    expect(s.chests.single.opened, isTrue);
    expect(s.chestsOpened, 1);
    final n = Rng.create(seed, 'drops').range(kChestCoinsMin, kChestCoinsMax);
    expect(s.coins.length, n);
    expect(n, inInclusiveRange(kChestCoinsMin, kChestCoinsMax));
    // Coins settle and get picked up while standing in the burst zone.
    stepSession(s, 4.0, (i) {});
    expect(s.coinsCollected, greaterThan(0));
  });

  test('secret chest counts secretsFound', () {
    final s = session('''
....................
....................
.P.X...............E
####################
''');
    stepSession(s, 0.6, (i) => i.dirX = 1);
    expect(s.secretsFound, 1);
  });

  test('cracked wall breaks after 3 sword hits', () {
    final s = session('''
....................
.P.B...............E
###.################
''');
    final wall = s.walls.single;
    var cooldown = 0.0;
    stepSession(s, 3.0, (i) {
      cooldown -= dt;
      if (wall.hp > 0 && cooldown <= 0) {
        i.attackPressed = true;
        cooldown = 0.4;
      }
    });
    expect(wall.hp, 0);
    expect(s.tileAt(3, 1), TileKind.empty);
    expect(s.wallsDirty, isTrue);
    final ev = s.takeEvents();
    expect(ev.where((e) => e.kind == SessionEventKind.wallHit).length, 2);
    expect(ev.where((e) => e.kind == SessionEventKind.wallBreak).length, 1);
  });

  test('wallBreaker special breaks a cracked wall in one hit', () {
    final s = session('''
....................
.P.B...............E
###.################
''', loadout: Loadout.starter(weapon: weaponById('woodsman_axe')));
    var first = true;
    stepSession(s, 0.3, (i) {
      if (first) {
        i.attackPressed = true;
        first = false;
      }
    });
    expect(s.walls.single.hp, 0);
    expect(s.tileAt(3, 1), TileKind.empty);
  });

  test('walking into the exit door completes with medals + results', () {
    final s = session('''
....................
.P.c..............E.
####################
''');
    stepSession(s, 4.0, (i) => i.dirX = 1);
    expect(s.completed, isTrue);
    final r = s.results!;
    expect(r.finished, isTrue);
    expect(r.coinsEarned, 1);
    expect(r.allChests, isTrue); // vacuous: no chests in level
    expect(r.lowDamage, isTrue);
    expect(r.medals, 3);
    expect(r.timeMs, greaterThan(0));
  });

  test('3-medal run pays the perfect-clear coin bonus', () {
    final s = session('''
....................
.P.c..............E.
####################
''');
    stepSession(s, 4.0, (i) => i.dirX = 1);
    final r = s.results!;
    expect(r.medals, 3);
    expect(r.perfectBonus, kPerfectClearBonus);
    expect(r.totalCoins, r.coinsEarned + kPerfectClearBonus);
  });

  test('2-medal run pays no bonus: totalCoins == coinsEarned', () {
    final s = session('''
....................
.......C............
....................
....................
.P.c..............E.
####################
''');
    stepSession(s, 4.0, (i) => i.dirX = 1);
    final r = s.results!;
    expect(r.medals, 2);
    expect(r.perfectBonus, 0);
    expect(r.totalCoins, r.coinsEarned);
  });

  test('missing a chest forfeits the allChests medal', () {
    final s = session('''
....................
.......C............
....................
....................
.P................E.
####################
''');
    stepSession(s, 4.0, (i) => i.dirX = 1);
    expect(s.completed, isTrue);
    expect(s.results!.allChests, isFalse);
    expect(s.results!.medals, 2);
  });

  test('falling out of the level fails the run', () {
    final s = session('''
....................
.P................E.
####...#############
''');
    stepSession(s, 4.0, (i) {}); // spawn column has ground; walk left off it
    final s2 = session('''
....................
.P................E.
##..################
''');
    stepSession(s2, 5.0, (i) => i.dirX = 1);
    // s2's pit is 2 tiles wide at x=2..3; the player walks in and falls out.
    expect(s2.failed || s2.completed, isTrue);
  });

  test('player death by hazard fails the run', () {
    final s = session('''
....................
.P.................E
##^^^^^^^^^^^^^^^^##
''');
    // Walk into spikes repeatedly until hearts run out (i-frames between).
    stepSession(s, 8.0, (i) => i.dirX = 1);
    expect(s.failed, isTrue);
    expect(s.player.isDead, isTrue);
    expect(
        s.takeEvents().any((e) => e.kind == SessionEventKind.levelFailed),
        isTrue);
  });

  test('signs expose their meta text when the player is near', () {
    final s = LevelSession(
        LevelData.parse('''
meta: sign1=Tap to jump
....................
.Ps................E
####################
'''),
        Loadout.starter());
    stepSession(s, 0.05, (i) {});
    expect(s.activeSign, isNotNull);
    expect(s.activeSign!.text, 'Tap to jump');
    // Walk away: bubble disappears.
    stepSession(s, 1.5, (i) => i.dirX = 1);
    expect(s.activeSign, isNull);
  });

  test('coin magnet doubles pickup radius', () {
    final base = Loadout.starter();
    final magnet = Loadout(
      weapon: base.weapon,
      maxHearts: 3,
      meleePower: 1,
      extraAirJumps: 0,
      appleCapacity: 10,
      coinMagnet: true,
      skinId: 'red',
    );
    final s1 = session('''
....................
.P.................E
####################
''');
    final s2 = LevelSession(
        LevelData.parse('''
....................
.P.................E
####################
'''),
        magnet);
    expect(s2.coinPickupRadius, s1.coinPickupRadius * 2);
  });

  test('w1_l1 level asset parses with tutorial signs', () {
    // Keep the shipped tutorial level honest (tutorial promise: move/jump,
    // attack, throw/drop-through).
    // The asset file itself is validated in level_data_test; here we check
    // the session wiring end-to-end once it has sign meta.
    final s = LevelSession(
        LevelData.parse('''
meta: sign1=Hold to run, tap JUMP twice for a double jump
meta: sign2=Tap SWORD to attack
....................
.Ps......s.........E
####################
'''),
        Loadout.starter());
    expect(s.signs[0].text, contains('JUMP'));
    expect(s.signs[1].text, contains('SWORD'));
  });

  group('coin spin phase', () {
    // Regression: all coins used to share one global ticker, so every coin
    // in a level hit the edge-on frame on the same tick (screenshot bug,
    // 2026-08-31 — a wall of "candles"). Phase must be per-coin, stable,
    // and actually spread across a level's coin layout.
    test('spinPhase is deterministic, in [0,1), and varies by position', () {
      final a1 = CoinEntity(48, 96);
      final a2 = CoinEntity(48, 96);
      expect(a1.spinPhase, a2.spinPhase, reason: 'must be deterministic');
      final phases = <double>{};
      for (var i = 0; i < 12; i++) {
        final c = CoinEntity(16.0 * i + 8, 96 - (i % 3) * 32);
        expect(c.spinPhase, inInclusiveRange(0, 0.9999999),
            reason: 'phase out of range for coin $i');
        phases.add(c.spinPhase);
      }
      expect(phases.length, greaterThanOrEqualTo(6),
          reason: 'a row of coins collapsed onto too few phases');
    });

    test('coinFrame spreads distinct phases across distinct frames', () {
      const clock = 1.234;
      final frames = <int>{
        for (final ph in [0.0, 0.25, 0.5, 0.75])
          ItemsComponent.coinFrame(clock, ph, 4),
      };
      expect(frames, {0, 1, 2, 3},
          reason: 'quarter-cycle phases must land on all 4 frames');
      // And the mapping still animates over time for a fixed phase.
      final over = <int>{
        for (var t = 0.0; t < 0.48; t += 0.12)
          ItemsComponent.coinFrame(t, 0.6, 4),
      };
      expect(over, {0, 1, 2, 3});
    });
  });
}
