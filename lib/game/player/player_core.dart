// game/player/player_core.dart — the player brain: movement, jumps, combat
// timers, damage. Pure Dart so game-feel is headless-testable; the Flame
// component only reads state from here and draws.

import '../input_intent.dart';
import '../physics.dart';
import '../tuning.dart';

enum PlayerState { idle, run, jump, fall, attack, roll, hurt, dead }

enum PlayerEvent {
  jumped,
  airJumped,
  landed,
  attacked,
  rolled,
  airDashed,
  hurt,
  died,
  droppedThrough,
}

class PlayerCore {
  final Body body;
  final TileQuery tileAt;

  // Loadout (injected from save/meta).
  final int maxHearts;
  final int weaponDamage;
  final double weaponRange;
  final int extraAirJumps; // triple-jump special = +1
  final double meleePower;
  // AKP-4b: lunge special (Skypiercer) — swings burst you forward. The
  // specialText has promised this since P-M4; before AKP-4 it was stats-only.
  final bool hasLunge;

  int hearts;
  int facing = 1; // -1 left, 1 right
  PlayerState state = PlayerState.idle;

  // Timers.
  double coyote = 0;
  double jumpBuffer = 0;
  double attackBuffer = 0;
  double iFrames = 0;
  double attackTime = 0; // remaining swing time
  double comboWindow = 0;
  double hurtTime = 0;
  double rollTime = 0;
  double rollCooldown = 0;
  int comboIndex = 0; // 0..kComboHits-1, index of CURRENT swing
  int airJumpsUsed = 0;
  /// Seconds since the last jump impulse, and whether an early release is
  /// waiting for [kMinJumpHold] to elapse before it cuts the rise.
  double sinceJump = 999;
  bool cutArmed = false;
  bool airDashUsed = false; // AKP-2b: one air dash per airborne period
  bool _airDashing = false; // current roll started mid-air (gravity off)
  bool wasOnGround = false;
  bool jumpWasHeld = false;

  /// Events emitted since the last [takeEvents] call (sfx/fx hooks).
  final List<PlayerEvent> _events = [];

  PlayerCore({
    required double x,
    required double y,
    required this.tileAt,
    this.maxHearts = kBaseMaxHearts,
    this.weaponDamage = 3,
    this.weaponRange = 18,
    this.extraAirJumps = 0,
    this.meleePower = 1.0,
    this.hasLunge = false,
  })  : body = Body(x: x, y: y, w: 12, h: 20),
        hearts = maxHearts;

  bool get isDead => state == PlayerState.dead;

  List<PlayerEvent> takeEvents() {
    if (_events.isEmpty) return const []; // called every frame: skip the copy
    final out = List<PlayerEvent>.from(_events);
    _events.clear();
    return out;
  }

  bool get attacking => attackTime > 0;

  bool get rolling => rollTime > 0;
  bool get airDashing => _airDashing && rolling;

  /// Active attack hitbox (null when not in the damage window).
  ({double x, double y, double w, double h, int damage})? get attackHitbox {
    if (!attacking) return null;
    // Damage window: middle 60% of the swing.
    final t = 1 - attackTime / kAttackDuration;
    if (t < 0.2 || t > 0.8) return null;
    final reach = weaponRange + 6;
    final x = facing > 0 ? body.right : body.left - reach;
    final isFinisher = comboIndex == kComboHits - 1;
    final dmg = ((weaponDamage * (isFinisher ? 1.5 : 1.0)) * meleePower)
        .round()
        .clamp(1, 99);
    return (x: x, y: body.top - 4, w: reach, h: body.h + 8, damage: dmg);
  }

  void update(double dt, InputIntent input) {
    if (state == PlayerState.dead) return;

    // --- timers
    coyote = (coyote - dt).clamp(0, 10);
    jumpBuffer = (jumpBuffer - dt).clamp(0, 10);
    attackBuffer = (attackBuffer - dt).clamp(0, 10);
    iFrames = (iFrames - dt).clamp(0, 10);
    comboWindow = (comboWindow - dt).clamp(0, 10);
    hurtTime = (hurtTime - dt).clamp(0, 10);
    rollTime = (rollTime - dt).clamp(0, 10);
    rollCooldown = (rollCooldown - dt).clamp(0, 10);
    if (attackTime > 0) {
      attackTime = (attackTime - dt).clamp(0, 10);
      if (attackTime == 0) comboWindow = kComboWindow;
    }

    if (input.jumpPressed) jumpBuffer = kJumpBufferTime;
    if (input.attackPressed) attackBuffer = kAttackBufferTime;

    final stunned = hurtTime > 0;

    // --- horizontal
    // A roll is a commitment: velocity is locked to facing until it ends.
    final dir =
        (stunned || rolling) ? 0.0 : input.dirX.clamp(-1.0, 1.0);
    if (rolling) body.vx = facing * kRollSpeed;
    if (dir != 0) {
      facing = dir > 0 ? 1 : -1;
      var accel = body.onGround ? kGroundAccel : kAirAccel;
      // Turnaround assist: reversing direction is the most latency-sensitive
      // input on touch — boost accel while velocity opposes the stick.
      if (body.vx != 0 && body.vx.sign != dir.sign) {
        accel *= kTurnAccelMultiplier;
      }
      body.vx += dir * accel * dt;
      if (body.vx.abs() > kRunSpeed) body.vx = kRunSpeed * body.vx.sign;
    } else if (body.onGround && !rolling) {
      final f = kGroundFriction * dt;
      if (body.vx.abs() <= f) {
        body.vx = 0;
      } else {
        body.vx -= f * body.vx.sign;
      }
    }

    // --- jumping
    final grounded = body.onGround || groundBelow(body, tileAt);
    if (grounded) {
      coyote = kCoyoteTime;
      airJumpsUsed = 0;
      airDashUsed = false; // AKP-2b: landing re-arms the air dash
    }
    var dropThrough = false;
    if (jumpBuffer > 0 && !stunned && !rolling) {
      if (input.down && grounded && platformBelow(body, tileAt)) {
        // Drop through one-way platform.
        dropThrough = true;
        jumpBuffer = 0;
        body.y += 2;
        _events.add(PlayerEvent.droppedThrough);
      } else if (input.down && grounded) {
        // DOWN+JUMP on solid ground = roll: quick commit-dodge with
        // i-frames. Previously this input combination ate the jump. While
        // the roll cools down the press is consumed (never an accidental
        // jump — DOWN+JUMP always means "roll" on solid ground).
        jumpBuffer = 0;
        _tryRoll();
      } else if (coyote > 0) {
        body.vy = -kJumpSpeed;
        coyote = 0;
        jumpBuffer = 0;
        sinceJump = 0;
        cutArmed = false;
        _events.add(PlayerEvent.jumped);
      } else if (airJumpsUsed < kMaxAirJumps + extraAirJumps) {
        body.vy = -kAirJumpSpeed;
        airJumpsUsed++;
        jumpBuffer = 0;
        sinceJump = 0;
        cutArmed = false;
        _events.add(PlayerEvent.airJumped);
      }
    }
    // AKP-2a: dedicated dash/roll button — same commit-dodge as the
    // DOWN+JUMP chord. On the ground it is the classic roll; in the air
    // (AKP-2b, owner-confirmed 2026-07-25) it is AK's air dash: a flat
    // horizontal burst with gravity suspended, once per airborne period.
    // Rejected presses are simply dropped: a dash button must never buffer
    // into a surprise roll half a second later.
    if (input.rollPressed && !stunned && !rolling) {
      if (grounded) {
        _tryRoll();
      } else if (kAirDashEnabled && !airDashUsed) {
        _tryRoll(air: true);
      }
    }

    // Variable height: releasing jump early cuts upward velocity — but never
    // below kMinJumpSpeed. Without the floor, a quick tap on a touch button
    // (one or two frames of hold) left ~7px of rise: not enough to clear a
    // single 16px block, so tap-jumps read as "the jump button didn't work".
    // The floor guarantees every registered jump clears one tile; holding
    // still buys the full 2+ tiles.
    sinceJump += dt;
    if (jumpWasHeld && !input.jumpHeld && body.vy < 0) cutArmed = true;
    if (cutArmed && body.vy < 0 && sinceJump >= kMinJumpHold) {
      body.vy *= kJumpCutMultiplier;
      cutArmed = false;
    }
    if (body.vy >= 0) cutArmed = false;
    jumpWasHeld = input.jumpHeld;

    // --- attack
    if (attackBuffer > 0 && !attacking && !stunned && !rolling) {
      attackBuffer = 0;
      comboIndex = comboWindow > 0 ? (comboIndex + 1) % kComboHits : 0;
      comboWindow = 0;
      attackTime = kAttackDuration;
      // AKP-4b: lunge special — a forward burst at swing start, ground or
      // air. Friction/walls handle the rest; jump height is untouched.
      if (hasLunge) body.vx = facing * kLungeSpeed;
      _events.add(PlayerEvent.attacked);
    }

    // --- gravity + integrate
    // Asymmetric gravity: apex hang while jump is held (extra beat of air
    // control at the top of the arc), heavier gravity on the way down (snappy
    // landings). Rise gravity is untouched, so jump HEIGHT never changes —
    // the clearance tests pin that.
    var g = kGravity;
    if (!body.onGround && input.jumpHeld && body.vy.abs() < kApexHangSpeed) {
      g = kGravity * kApexGravityMultiplier;
    } else if (body.vy > 0) {
      g = kGravity * kFallGravityMultiplier;
    }
    // AKP-2b: an air dash holds its height — gravity fully suspended and
    // vertical velocity zeroed for the whole dash window.
    if (_airDashing) {
      if (rolling) {
        g = 0;
        body.vy = 0;
      } else {
        _airDashing = false;
      }
    }
    body.vy += g * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt,
        dropThrough: dropThrough || input.down,
        ceilingNudge: kCeilingCornerNudge);
    if (body.onGround && !wasOnGround) _events.add(PlayerEvent.landed);
    wasOnGround = body.onGround;

    // --- hazards
    if (iFrames <= 0 && touchesHazard(body, tileAt)) {
      damage(1, from: body.centerX, hazardEject: true);
    }

    // --- state
    if (state != PlayerState.dead) {
      if (hurtTime > 0) {
        state = PlayerState.hurt;
      } else if (rolling) {
        state = PlayerState.roll;
      } else if (attacking) {
        state = PlayerState.attack;
      } else if (!body.onGround) {
        state = body.vy < 0 ? PlayerState.jump : PlayerState.fall;
      } else {
        state = body.vx.abs() > 5 ? PlayerState.run : PlayerState.idle;
      }
    }
  }

  /// Start a roll if allowed (not mid-attack, cooldown elapsed). Shared by
  /// the DOWN+JUMP chord and the dedicated dash/roll button (AKP-2a).
  /// With [air] (AKP-2b) it becomes the air dash: same speed/i-frames but
  /// height is held for the duration and the charge arms only on landing.
  void _tryRoll({bool air = false}) {
    if (attacking || rollCooldown > 0) return;
    rollTime = kRollDuration;
    rollCooldown = kRollDuration + kRollCooldown;
    if (iFrames < kRollIFrames) iFrames = kRollIFrames;
    body.vx = facing * kRollSpeed;
    if (air) {
      airDashUsed = true;
      _airDashing = true;
      body.vy = 0;
    }
    _events.add(air ? PlayerEvent.airDashed : PlayerEvent.rolled);
  }

  /// Apply [amount] hearts of damage from a source at x=[from].
  /// Returns true if damage landed (not invulnerable).
  ///
  /// [hazardEject] (AKP-6b): hazard-tile damage launches the player up and
  /// along the direction of travel so a pit throws you back OUT — the
  /// normal knockback left you at the pit bottom, chain-dying every time
  /// the i-frames lapsed.
  bool damage(int amount, {required double from, bool hazardEject = false}) {
    if (iFrames > 0 || state == PlayerState.dead) return false;
    hearts -= amount;
    iFrames = kHurtIFrames;
    hurtTime = 0.25;
    attackTime = 0;
    rollTime = 0;
    if (hazardEject) {
      final travel = body.vx.abs() > 5 ? body.vx.sign : -facing.toDouble();
      body.vx = travel * kHazardEjectSpeedX;
      body.vy = -kHazardEjectSpeedY;
    } else {
      final dir = body.centerX >= from ? 1 : -1;
      body.vx = dir * kKnockbackSpeed;
      body.vy = -kKnockbackSpeed * 0.6;
    }
    body.onGround = false;
    if (hearts <= 0) {
      hearts = 0;
      state = PlayerState.dead;
      _events.add(PlayerEvent.died);
    } else {
      _events.add(PlayerEvent.hurt);
    }
    return true;
  }

  /// Put the player back at [x],[y] after a checkpoint death: full hearts,
  /// every timer cleared, a grace window so the respawn can't chain into the
  /// same threat that just killed them.
  void reviveAt(double x, double y, {double iFrames = 1.5}) {
    body
      ..x = x
      ..y = y
      ..vx = 0
      ..vy = 0
      ..onGround = false;
    hearts = maxHearts;
    state = PlayerState.idle;
    this.iFrames = iFrames;
    hurtTime = 0;
    attackTime = 0;
    attackBuffer = 0;
    rollTime = 0;
    rollCooldown = 0;
    jumpBuffer = 0;
    coyote = 0;
    airJumpsUsed = 0;
    airDashUsed = false;
    sinceJump = 999;
    cutArmed = false;
    comboIndex = 0;
    comboWindow = 0;
    _events.clear();
  }

  void kill() {
    if (state == PlayerState.dead) return;
    hearts = 0;
    state = PlayerState.dead;
    _events.add(PlayerEvent.died);
  }
}
