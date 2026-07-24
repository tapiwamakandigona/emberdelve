// Headless enemy AI tests: patrol/turn logic, flyer/hopper behavior,
// damage → hurt flash → death.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/enemies/enemy_core.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 120;

final arena = LevelData.parse('''
....................
....................
....................
.P.................E
##..######........##
''');

void stepEnemy(EnemyCore e, LevelData l, double seconds,
    {double playerX = -999, double playerY = -999}) {
  final frames = (seconds / dt).round();
  for (var i = 0; i < frames; i++) {
    e.update(dt, l.tileAt, playerX: playerX, playerY: playerY);
  }
}

void main() {
  test('thornling patrols and turns at platform edges', () {
    // Platform spans tiles x=4..9 (px 64..160), enemy starts mid-platform.
    final e = ThornlingCore(x: 100, y: 4 * kTileSize - 22);
    stepEnemy(e, arena, 0.2);
    expect(e.body.onGround, isTrue);
    expect(e.facing, 1);
    // Walk right until the edge: must turn around, never fall off.
    stepEnemy(e, arena, 3.0);
    expect(e.body.onGround, isTrue);
    expect(e.body.right, lessThanOrEqualTo(160 + 1));
    expect(e.body.left, greaterThanOrEqualTo(64 - 1));
    // Saw both directions over a long patrol.
    var sawLeft = false, sawRight = false;
    for (var i = 0; i < 600; i++) {
      e.update(dt, arena.tileAt, playerX: -999, playerY: -999);
      if (e.facing < 0) sawLeft = true;
      if (e.facing > 0) sawRight = true;
    }
    expect(sawLeft && sawRight, isTrue);
  });

  test('thornling turns at walls', () {
    final l = LevelData.parse('''
#..................#
#P................E#
####################
''');
    final e = ThornlingCore(x: 40, y: 2 * kTileSize - 22);
    stepEnemy(e, l, 8.0);
    // Stays inside the walled corridor.
    expect(e.body.left, greaterThanOrEqualTo(kTileSize - 1));
    expect(e.body.right, lessThanOrEqualTo(19 * kTileSize + 1));
  });

  test('damage flashes, then kills at 0 hp', () {
    final e = ThornlingCore(x: 100, y: 42);
    expect(e.hp, 6);
    expect(e.damage(4), isTrue);
    expect(e.alive, isTrue);
    expect(e.hurtFlash, greaterThan(0));
    expect(e.damage(4), isTrue);
    expect(e.alive, isFalse);
    expect(e.damage(1), isFalse); // dead enemies absorb nothing
  });

  test('ashbat sines around its anchor within amplitude', () {
    final e = AshbatCore(x: 200, y: 40);
    var minY = 1e9, maxY = -1e9, minX = 1e9, maxX = -1e9;
    for (var i = 0; i < 1200; i++) {
      e.update(dt, arena.tileAt, playerX: -999, playerY: -999);
      if (e.body.y < minY) minY = e.body.y;
      if (e.body.y > maxY) maxY = e.body.y;
      if (e.body.x < minX) minX = e.body.x;
      if (e.body.x > maxX) maxX = e.body.x;
    }
    expect(maxY - minY, closeTo(2 * AshbatCore.amplitude, 2));
    expect(maxX - minX, lessThanOrEqualTo(2 * AshbatCore.patrolHalf + 2));
  });

  test('hopper hops toward player in range, sits still otherwise', () {
    final l = LevelData.parse('''
....................
.P.................E
####################
''');
    final e = HopperCore(x: 160, y: 2 * kTileSize - 22);
    // No player nearby: stays put.
    stepEnemy(e, l, 1.0);
    expect(e.body.centerX, closeTo(160 + 12, 2));
    // Player within 6 tiles to the left: hops toward them.
    final x0 = e.body.centerX;
    stepEnemy(e, l, 1.5, playerX: 100, playerY: e.body.centerY);
    expect(e.body.centerX, lessThan(x0));
    expect(e.facing, -1);
  });

  test('sleeping enemies skip behavior but keep burn ticking', () {
    final e = ThornlingCore(x: 100, y: 4 * kTileSize - 22);
    stepEnemy(e, arena, 0.2); // settle
    e.sleeping = true;
    final x = e.body.x;
    e.burnLeft = 3.0;
    stepEnemy(e, arena, 2.05);
    expect(e.body.x, x); // didn't move
    expect(e.hp, 4); // 2 burn ticks landed
  });
}
