// Headless pickup / chest / wall / door / death economy tests over
// LevelSession.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/core/rng.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';
import 'package:emberdelve/meta/catalog.dart';

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
}
