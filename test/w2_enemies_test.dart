// World 2 enemies: Soot Creeper (relentless walker, drops off ledges) and
// Cinder Diver (anchor hover -> telegraph -> dive -> climb back).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/enemies/enemy_core.dart';
import 'package:emberwood/game/level/level_data.dart';


const dt = 1 / 60;

// Ledge world: high platform on the left, floor below right.
final ledge = LevelData.parse('''
P.......................E
####......................
..........................
##########################
''');

void run(EnemyCore e, LevelData l, double seconds,
    {double px = -1000, double py = -1000}) {
  final frames = (seconds / dt).round();
  for (var i = 0; i < frames; i++) {
    e.update(dt, l.tileAt, playerX: px, playerY: py);
  }
}

void main() {
  test('soot creeper walks off ledges and keeps crawling below', () {
    final e = SootCreeperCore(x: 4.0, y: 16 - 22);
    e.facing = 1;
    run(e, ledge, 4.0);
    expect(e.alive, isTrue);
    expect(e.body.onGround, isTrue);
    // It must have fallen to the lower floor (row 3 tops at y=48).
    expect(e.body.bottom, closeTo(48, 1));
  });

  test('soot creeper turns at walls, is tanky', () {
    final e = SootCreeperCore(x: 380, y: 48 - 22);
    e.facing = 1;
    run(e, ledge, 3.0); // hits the right world edge (solid beyond bounds)
    expect(e.facing, -1, reason: 'should have bounced off the wall');
    expect(e.hp, 9);
    e.damage(6);
    expect(e.alive, isTrue, reason: 'tanky: survives 6 damage');
  });

  test('cinder diver idles at anchor until the player crosses below', () {
    final e = CinderDiverCore(x: 10 * 16.0, y: 16.0);
    run(e, ledge, 1.0); // player far away
    expect(e.phase, 'idle');
    expect((e.body.x - e.anchorX).abs(), lessThan(8));
    // Player passes underneath -> telegraph, not instant dive.
    run(e, ledge, dt * 2, px: e.centerX + 8, py: e.centerY + 3 * 16);
    expect(e.phase, 'telegraph');
    expect(e.telegraphing, isTrue);
  });

  test('cinder diver dives after the telegraph and climbs back home', () {
    final e = CinderDiverCore(x: 10 * 16.0, y: 16.0);
    final px = e.centerX + 8.0, py = e.centerY + 3 * 16.0;
    run(e, ledge, CinderDiverCore.telegraphTime + dt * 3, px: px, py: py);
    expect(e.phase, 'dive');
    expect(e.body.vy, greaterThan(0), reason: 'dive is always downward');
    // Let the dive land and the climb finish.
    run(e, ledge, 6.0);
    expect(e.phase, 'idle');
    expect((e.body.x - e.anchorX).abs(), lessThan(8));
    expect((e.body.y - e.anchorY).abs(), lessThan(8));
  });

  test('legend chars S and D spawn the new kinds', () {
    final l = LevelData.parse('''
....D....................
P...S...................E
##########################
''');
    expect(
        l.spawns.where((s) => s.kind == SpawnKind.sootCreeper).length, 1);
    expect(
        l.spawns.where((s) => s.kind == SpawnKind.cinderDiver).length, 1);
  });
}
