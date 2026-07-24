// Headless game-feel tests: PlayerCore + physics stepped at dt = 1/120
// against LevelData.parse fixtures. These pin the M2 acceptance criteria:
// jump heights, coyote/buffer windows, variable height, one-way platforms,
// wall collision, hazard i-frames, knockback.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/player/player_core.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 120;

/// Flat runway: 40 tiles wide, ground at row 8.
final flat = LevelData.parse('''
........................................
........................................
........................................
........................................
........................................
........................................
........................................
.P....................................E.
########################################
''');

PlayerCore corePlayer(LevelData l, {int extraAirJumps = 0}) {
  final s = l.playerSpawn;
  final c = PlayerCore(
    x: s.x * kTileSize + 2,
    y: (s.y + 1) * kTileSize - 20,
    tileAt: l.tileAt,
    extraAirJumps: extraAirJumps,
  );
  // Settle onto the ground.
  final idle = InputIntent();
  for (var i = 0; i < 30; i++) {
    c.update(dt, idle);
  }
  c.takeEvents();
  return c;
}

/// Step [seconds] with a per-frame intent configurator.
void step(PlayerCore c, double seconds, void Function(InputIntent) config,
    {void Function(PlayerCore)? onFrame}) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    config(intent);
    c.update(dt, intent);
    onFrame?.call(c);
  }
}

void main() {
  test('jump from flat ground clears 2 tiles but not 4', () {
    final c = corePlayer(flat);
    final startY = c.body.y;
    var minY = startY;
    var first = true;
    step(c, 1.0, (i) {
      i.jumpHeld = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    }, onFrame: (c) {
      if (c.body.y < minY) minY = c.body.y;
    });
    final rise = startY - minY;
    expect(rise, greaterThan(2 * kTileSize));
    expect(rise, lessThan(4 * kTileSize));
  });

  test('double jump total rise clears 3.5 tiles', () {
    final c = corePlayer(flat);
    final startY = c.body.y;
    var minY = startY;
    var airJumped = false;
    var first = true;
    step(c, 1.6, (i) {
      i.jumpHeld = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      } else if (!airJumped && c.body.vy >= 0 && !c.body.onGround) {
        i.jumpPressed = true; // second jump at apex
        airJumped = true;
      }
    }, onFrame: (c) {
      if (c.body.y < minY) minY = c.body.y;
    });
    expect(c.takeEvents(), contains(PlayerEvent.airJumped));
    expect(startY - minY, greaterThan(3.5 * kTileSize));
  });

  /// Ledge fixture: ground only under the spawn side; player runs off.
  LevelData ledge() => LevelData.parse('''
....................
....................
....................
.P.................E
######..........####
''');

  /// Run right until the player leaves the ground, then return the core.
  PlayerCore runOffLedge(PlayerCore c) {
    final intent = InputIntent()..dirX = 1;
    var frames = 0;
    while ((c.body.onGround || c.coyote >= kCoyoteTime) && frames < 600) {
      c.update(dt, intent);
      frames++;
    }
    expect(c.body.onGround, isFalse);
    c.takeEvents();
    return c;
  }

  test('coyote jump 0.08s after leaving a ledge is a GROUND jump', () {
    final c = runOffLedge(corePlayer(ledge()));
    step(c, 0.07, (i) {});
    var pressed = false;
    step(c, 0.05, (i) {
      if (!pressed) {
        i.jumpPressed = true;
        pressed = true;
      }
    });
    final ev = c.takeEvents();
    expect(ev, contains(PlayerEvent.jumped));
    expect(ev, isNot(contains(PlayerEvent.airJumped)));
  });

  test('jump 0.2s after leaving a ledge is NOT a coyote jump', () {
    final c = runOffLedge(corePlayer(ledge()));
    step(c, 0.2, (i) {});
    var pressed = false;
    step(c, 0.05, (i) {
      if (!pressed) {
        i.jumpPressed = true;
        pressed = true;
      }
    });
    final ev = c.takeEvents();
    expect(ev, isNot(contains(PlayerEvent.jumped)));
    expect(ev, contains(PlayerEvent.airJumped)); // fell back to the air jump
  });

  test('jump buffered 0.1s before landing fires on landing', () {
    final c = corePlayer(flat);
    // Get airborne with a jump, press jump again ~0.1s before touchdown.
    var first = true;
    step(c, 0.1, (i) {
      i.jumpHeld = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    c.takeEvents();
    // Burn the air jump far from the ground is unwanted — instead wait for
    // descent and press within the buffer window just before landing.
    // Exhaust the air jump first so only the buffer can produce a jump.
    var used = false;
    step(c, 0.05, (i) {
      if (!used) {
        i.jumpPressed = true; // consumes the air jump mid-flight
        used = true;
      }
    });
    c.takeEvents();
    // Fall until close to the ground (~0.08s out at terminal-ish speed).
    while (!c.body.onGround) {
      final framesToGround =
          ((flat.playerSpawn.y + 1) * kTileSize - 20 - c.body.y);
      if (c.body.vy > 0 && framesToGround < c.body.vy * 0.08) break;
      c.update(dt, InputIntent());
    }
    c.takeEvents();
    var pressed = false;
    step(c, 0.3, (i) {
      if (!pressed) {
        i.jumpPressed = true;
        pressed = true;
      }
    });
    final ev = c.takeEvents();
    expect(ev, contains(PlayerEvent.landed));
    expect(ev, contains(PlayerEvent.jumped));
  });

  test('variable height: early release rises less than full hold', () {
    double riseFor(double holdSeconds) {
      final c = corePlayer(flat);
      final startY = c.body.y;
      var minY = startY;
      var t = 0.0;
      var first = true;
      step(c, 1.0, (i) {
        t += dt;
        i.jumpHeld = t < holdSeconds;
        if (first) {
          i.jumpPressed = true;
          first = false;
        }
      }, onFrame: (c) {
        if (c.body.y < minY) minY = c.body.y;
      });
      return startY - minY;
    }

    final short = riseFor(0.08);
    final full = riseFor(1.0);
    expect(short, lessThan(full * 0.75));
    expect(short, greaterThan(kTileSize * 0.5)); // still a real hop
  });

  /// One-way platform fixture: platform row above the ground.
  LevelData platformLevel() => LevelData.parse('''
....................
....................
....====............
....................
.P.................E
####################
''');

  /// Double-jump straight up (platform sits 3 tiles above the ground).
  void doubleJumpUp(PlayerCore c) {
    var first = true;
    var airJumped = false;
    step(c, 1.4, (i) {
      i.jumpHeld = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      } else if (!airJumped && !c.body.onGround && c.body.vy > -60) {
        i.jumpPressed = true;
        airJumped = true;
      }
    });
  }

  test('one-way platform: lands from above, jumps up through', () {
    final l = platformLevel();
    final c = corePlayer(l);
    // Walk under the platform, stop, double-jump up through it, land on top.
    step(c, 0.45, (i) => i.dirX = 1);
    step(c, 0.2, (i) {}); // ground friction kills vx (no air drift)
    doubleJumpUp(c);
    // No ceiling hit while passing through from below.
    expect(c.body.hitCeiling, isFalse);
    expect(c.body.onGround, isTrue);
    final platTop = 2 * kTileSize;
    expect(c.body.bottom, closeTo(platTop, 0.5));
  });

  test('one-way platform: down+jump drops through', () {
    final l = platformLevel();
    final c = corePlayer(l);
    // Get on top of the platform first.
    step(c, 0.45, (i) => i.dirX = 1);
    step(c, 0.2, (i) {});
    doubleJumpUp(c);
    expect(c.body.bottom, closeTo(2 * kTileSize, 0.5));
    c.takeEvents();
    // Down + jump: drop through.
    var pressed = false;
    step(c, 0.5, (i) {
      i.down = true;
      if (!pressed) {
        i.jumpPressed = true;
        pressed = true;
      }
    });
    expect(c.takeEvents(), contains(PlayerEvent.droppedThrough));
    // Ends up on the real ground below.
    expect(c.body.bottom, closeTo(5 * kTileSize, 0.5));
  });

  test('wall stops horizontal movement', () {
    final l = LevelData.parse('''
..........#.........
.P........#........E
####################
''');
    final c = corePlayer(l);
    step(c, 2.0, (i) => i.dirX = 1);
    expect(c.body.right, closeTo(10 * kTileSize, 0.5));
    expect(c.body.hitWall, isTrue);
  });

  test('spikes damage once, then i-frames protect', () {
    final l = LevelData.parse('''
....................
.P.................E
###^^###############
''');
    final c = corePlayer(l);
    expect(c.hearts, kBaseMaxHearts);
    // Walk onto the spikes.
    step(c, 0.6, (i) => i.dirX = 1);
    expect(c.hearts, kBaseMaxHearts - 1);
    expect(c.iFrames, greaterThan(0));
    // Stay in the hazard for a few frames: no double dip inside i-frames.
    final heartsAfterHit = c.hearts;
    step(c, 0.3, (i) {});
    expect(c.hearts, heartsAfterHit);
  });

  test('knockback pushes away from the damage source', () {
    final c = corePlayer(flat);
    final fromLeft = c.body.centerX - 10;
    c.damage(1, from: fromLeft);
    expect(c.body.vx, greaterThan(0)); // pushed right, away from source
    expect(c.body.vy, lessThan(0)); // pops up
    final c2 = corePlayer(flat);
    c2.damage(1, from: c2.body.centerX + 10);
    expect(c2.body.vx, lessThan(0)); // pushed left
  });
}
