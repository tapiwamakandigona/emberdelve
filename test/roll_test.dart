// Roll verb (DOWN+JUMP on solid ground): commit-dodge with i-frames.
// Previously that input combination silently ate the jump on solid ground;
// drop-through on one-way platforms is unchanged.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/player/player_core.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 60;

final flat = LevelData.parse('''
........................................
........................................
........................................
........................................
.P....................................E.
########################################
''');

final platformLevel = LevelData.parse('''
........................................
..P...................................E.
.======.................................
........................................
########################################
''');

final spiked = LevelData.parse('''
........................................
........................................
.P....................................E.
######^^^^##############################
######^^^^##############################
''');

PlayerCore settle(LevelData l) {
  final s = l.playerSpawn;
  final c = PlayerCore(
    x: s.x * kTileSize + 2,
    y: (s.y + 1) * kTileSize - 20,
    tileAt: l.tileAt,
  );
  final idle = InputIntent();
  for (var i = 0; i < 30; i++) {
    c.update(dt, idle);
  }
  c.takeEvents();
  return c;
}

void step(PlayerCore c, double seconds, void Function(InputIntent) config) {
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
  }
}

void main() {
  test('DOWN+JUMP on solid ground rolls: state, speed, event', () {
    final c = settle(flat);
    var first = true;
    final events = <PlayerEvent>[];
    step(c, 0.1, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    events.addAll(c.takeEvents());
    expect(events, contains(PlayerEvent.rolled));
    expect(events, isNot(contains(PlayerEvent.jumped)));
    expect(c.state, PlayerState.roll);
    expect(c.body.vx, closeTo(kRollSpeed * c.facing, 1));
  });

  test('roll grants i-frames and they expire with the roll', () {
    final c = settle(flat);
    var first = true;
    step(c, dt * 2, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    expect(c.rolling, isTrue);
    expect(c.iFrames, greaterThan(0));
    expect(c.iFrames, lessThanOrEqualTo(kRollIFrames));
    // Damage during the i-frame window is ignored.
    expect(c.damage(1, from: c.body.centerX + 5), isFalse);
    expect(c.hearts, c.maxHearts);
  });

  test('rolling across spikes with i-frames takes no damage', () {
    final c = settle(spiked);
    // Face right, then roll across the 4-tile spike strip (64px at 190px/s
    // = 0.34s < 0.28s i-frames + ~6px body inset each side).
    var first = true;
    step(c, kRollDuration, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    expect(c.hearts, c.maxHearts,
        reason: 'roll i-frames should carry the player over the spikes');
  });

  test('roll is locked: no steering, no attack, no jump mid-roll', () {
    final c = settle(flat);
    var first = true;
    step(c, 0.15, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      } else {
        // Try to fight the roll.
        i.dirX = -1;
        i.attackPressed = true;
        i.jumpPressed = true;
      }
    });
    final events = c.takeEvents();
    expect(c.rolling, isTrue);
    expect(c.body.vx, closeTo(kRollSpeed, 1)); // still full speed forward
    expect(events, isNot(contains(PlayerEvent.attacked)));
    expect(events, isNot(contains(PlayerEvent.jumped)));
    expect(events, isNot(contains(PlayerEvent.airJumped)));
  });

  test('roll ends and cooldown blocks an immediate second roll', () {
    final c = settle(flat);
    var first = true;
    step(c, kRollDuration + 0.05, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    c.takeEvents();
    expect(c.rolling, isFalse);
    // Still cooling down: a second DOWN+JUMP does not roll.
    var pressed = false;
    step(c, 0.05, (i) {
      i.down = true;
      if (!pressed) {
        i.jumpPressed = true;
        pressed = true;
      }
    });
    expect(c.takeEvents(), isNot(contains(PlayerEvent.rolled)));
    // After the cooldown (and settling) a new roll works.
    step(c, 1.0, (i) {});
    var again = false;
    step(c, 0.05, (i) {
      i.down = true;
      if (!again) {
        i.jumpPressed = true;
        again = true;
      }
    });
    expect(c.takeEvents(), contains(PlayerEvent.rolled));
  });

  test('DOWN+JUMP on a one-way platform still drops through (no roll)', () {
    final c = settle(platformLevel);
    var first = true;
    final events = <PlayerEvent>[];
    step(c, 0.2, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    events.addAll(c.takeEvents());
    expect(events, contains(PlayerEvent.droppedThrough));
    expect(events, isNot(contains(PlayerEvent.rolled)));
  });

  test('getting hurt after i-frames expire cancels the roll', () {
    final c = settle(flat);
    var first = true;
    step(c, dt, (i) {
      i.down = true;
      if (first) {
        i.jumpPressed = true;
        first = false;
      }
    });
    expect(c.rolling, isTrue);
    c.iFrames = 0; // simulate the i-frame window ending mid-roll
    expect(c.damage(1, from: c.body.centerX + 5), isTrue);
    expect(c.rolling, isFalse);
    c.update(dt, InputIntent()); // state machine settles next frame
    expect(c.state, PlayerState.hurt);
  });

  // ---- AKP-2a: dedicated dash/roll button (InputIntent.rollPressed) -------

  group('dash button (rollPressed)', () {
    test('press on solid ground rolls: state, speed, i-frames, event', () {
      final c = settle(flat);
      var first = true;
      step(c, 0.1, (i) {
        if (first) {
          i.rollPressed = true;
          first = false;
        }
      });
      final events = c.takeEvents();
      expect(events, contains(PlayerEvent.rolled));
      expect(events, isNot(contains(PlayerEvent.jumped)));
      expect(c.state, PlayerState.roll);
      expect(c.body.vx, closeTo(kRollSpeed * c.facing, 1));
      expect(c.iFrames, greaterThan(0));
    });

    test('press in the air is dropped (ground-only, no buffering)', () {
      final c = settle(flat);
      // Jump, then press dash mid-air.
      var jumped = false;
      step(c, dt * 2, (i) {
        if (!jumped) {
          i.jumpPressed = true;
          jumped = true;
        }
        i.jumpHeld = true;
      });
      c.takeEvents();
      expect(c.body.onGround, isFalse, reason: 'must be airborne');
      var pressed = false;
      step(c, 0.1, (i) {
        i.jumpHeld = true;
        if (!pressed) {
          i.rollPressed = true;
          pressed = true;
        }
      });
      expect(c.takeEvents(), isNot(contains(PlayerEvent.rolled)));
      // And the dropped press must NOT fire later on landing (no buffer).
      step(c, 1.0, (i) {});
      expect(c.takeEvents(), isNot(contains(PlayerEvent.rolled)));
    });

    test('press respects the roll cooldown', () {
      final c = settle(flat);
      var first = true;
      step(c, kRollDuration + 0.05, (i) {
        if (first) {
          i.rollPressed = true;
          first = false;
        }
      });
      c.takeEvents();
      expect(c.rolling, isFalse);
      var pressed = false;
      step(c, 0.05, (i) {
        if (!pressed) {
          i.rollPressed = true;
          pressed = true;
        }
      });
      expect(c.takeEvents(), isNot(contains(PlayerEvent.rolled)),
          reason: 'cooldown must block the dash button too');
    });

    test('press mid-attack is dropped', () {
      final c = settle(flat);
      var first = true;
      step(c, dt * 2, (i) {
        if (first) {
          i.attackPressed = true;
          first = false;
        }
      });
      c.takeEvents();
      expect(c.attacking, isTrue);
      var pressed = false;
      step(c, dt * 2, (i) {
        if (!pressed) {
          i.rollPressed = true;
          pressed = true;
        }
      });
      expect(c.takeEvents(), isNot(contains(PlayerEvent.rolled)));
    });
  });
}
