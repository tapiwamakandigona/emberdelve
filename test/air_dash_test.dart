// Air dash (AKP-2b, owner-confirmed 2026-07-25): the dash button fires
// mid-air — flat horizontal burst at kRollSpeed with gravity suspended for
// the roll window, i-frames as on the ground roll, and exactly ONE air dash
// per airborne period (landing re-arms it).
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

/// Jump and coast to mid-air (clearly past coyote/groundBelow).
void launch(PlayerCore c) {
  var first = true;
  step(c, 0.18, (i) {
    if (first) {
      i.jumpPressed = true;
      first = false;
    }
  });
  expect(c.body.onGround, isFalse, reason: 'setup: must be airborne');
  c.takeEvents();
}

void main() {
  test('dash button mid-air air-dashes: event, flat flight, full speed', () {
    final c = settle(flat);
    launch(c);
    final yAtDash = c.body.y;
    var first = true;
    step(c, kRollDuration * 0.8, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    final events = c.takeEvents();
    expect(events, contains(PlayerEvent.airDashed));
    expect(events, isNot(contains(PlayerEvent.rolled)));
    expect(c.rolling, isTrue);
    expect(c.airDashing, isTrue);
    expect(c.state, PlayerState.roll);
    expect(c.body.vx, closeTo(kRollSpeed * c.facing, 1));
    expect(c.body.vy, 0, reason: 'gravity suspended during the dash');
    expect(c.body.y, closeTo(yAtDash, 2.5),
        reason: 'an air dash holds its height');
  });

  test('gravity resumes the moment the dash window ends', () {
    final c = settle(flat);
    launch(c);
    var first = true;
    step(c, kRollDuration + 0.1, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    expect(c.rolling, isFalse);
    expect(c.airDashing, isFalse);
    expect(c.body.vy, greaterThan(0), reason: 'falling again after the dash');
  });

  test('only one air dash per airborne period; landing re-arms it', () {
    final c = settle(flat);
    launch(c);
    // Dash, then ride out the dash window while still airborne.
    var first = true;
    step(c, kRollDuration + dt * 2, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    expect(c.airDashUsed, isTrue);
    expect(c.rolling, isFalse);
    expect(c.body.onGround, isFalse,
        reason: 'setup: still airborne after the dash');
    c.takeEvents();
    // Second press in the SAME airtime. The roll cooldown alone would also
    // reject it in a normal jump arc, so force it elapsed to prove the
    // once-per-airtime guard holds on its own (long falls / cliff drops).
    c.rollCooldown = 0;
    var pressed = false;
    step(c, dt * 3, (i) {
      if (!pressed) {
        i.rollPressed = true;
        pressed = true;
      }
    });
    expect(c.takeEvents(), isNot(contains(PlayerEvent.airDashed)),
        reason: 'one air dash per airborne period');
    // Land: the charge is back, and a fresh airtime can dash again.
    step(c, 1.0, (i) {});
    expect(c.body.onGround, isTrue);
    expect(c.airDashUsed, isFalse, reason: 'landing re-arms the air dash');
    c.rollCooldown = 0;
    launch(c);
    first = true;
    step(c, 0.05, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    expect(c.takeEvents(), contains(PlayerEvent.airDashed));
  });

  test('air dash grants roll i-frames', () {
    final c = settle(flat);
    launch(c);
    var first = true;
    step(c, dt * 3, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    expect(c.airDashing, isTrue);
    expect(c.iFrames, greaterThan(0));
    expect(c.damage(1, from: c.body.centerX + 5), isFalse);
    expect(c.hearts, c.maxHearts);
  });

  test('ground dash is unchanged: no height hold, rolled event', () {
    final c = settle(flat);
    var first = true;
    step(c, dt * 3, (i) {
      if (first) {
        i.rollPressed = true;
        first = false;
      }
    });
    final events = c.takeEvents();
    expect(events, contains(PlayerEvent.rolled));
    expect(events, isNot(contains(PlayerEvent.airDashed)));
    expect(c.airDashing, isFalse);
  });
}
