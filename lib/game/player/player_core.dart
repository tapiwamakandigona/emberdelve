// game/player/player_core.dart — the player brain: movement, jumps, combat
// timers, damage. Pure Dart so game-feel is headless-testable; the Flame
// component only reads state from here and draws.

import '../input_intent.dart';
import '../physics.dart';
import '../tuning.dart';

enum PlayerState { idle, run, jump, fall, attack, hurt, dead }

enum PlayerEvent {
  jumped,
  airJumped,
  landed,
  attacked,
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
  int comboIndex = 0; // 0..kComboHits-1, index of CURRENT swing
  int airJumpsUsed = 0;
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
    if (attackTime > 0) {
      attackTime = (attackTime - dt).clamp(0, 10);
      if (attackTime == 0) comboWindow = kComboWindow;
    }

    if (input.jumpPressed) jumpBuffer = kJumpBufferTime;
    if (input.attackPressed) attackBuffer = kAttackBufferTime;

    final stunned = hurtTime > 0;

    // --- horizontal
    final dir = stunned ? 0.0 : input.dirX.clamp(-1.0, 1.0);
    if (dir != 0) {
      facing = dir > 0 ? 1 : -1;
      final accel = body.onGround ? kGroundAccel : kAirAccel;
      body.vx += dir * accel * dt;
      if (body.vx.abs() > kRunSpeed) body.vx = kRunSpeed * body.vx.sign;
    } else if (body.onGround) {
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
    }
    var dropThrough = false;
    if (jumpBuffer > 0 && !stunned) {
      if (input.down && grounded) {
        // Drop through one-way platform.
        dropThrough = true;
        jumpBuffer = 0;
        body.y += 2;
        _events.add(PlayerEvent.droppedThrough);
      } else if (coyote > 0) {
        body.vy = -kJumpSpeed;
        coyote = 0;
        jumpBuffer = 0;
        _events.add(PlayerEvent.jumped);
      } else if (airJumpsUsed < kMaxAirJumps + extraAirJumps) {
        body.vy = -kAirJumpSpeed;
        airJumpsUsed++;
        jumpBuffer = 0;
        _events.add(PlayerEvent.airJumped);
      }
    }
    // Variable height: releasing jump early cuts upward velocity.
    if (jumpWasHeld && !input.jumpHeld && body.vy < 0) {
      body.vy *= kJumpCutMultiplier;
    }
    jumpWasHeld = input.jumpHeld;

    // --- attack
    if (attackBuffer > 0 && !attacking && !stunned) {
      attackBuffer = 0;
      comboIndex = comboWindow > 0 ? (comboIndex + 1) % kComboHits : 0;
      comboWindow = 0;
      attackTime = kAttackDuration;
      _events.add(PlayerEvent.attacked);
    }

    // --- gravity + integrate
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt, dropThrough: dropThrough || input.down);
    if (body.onGround && !wasOnGround) _events.add(PlayerEvent.landed);
    wasOnGround = body.onGround;

    // --- hazards
    if (iFrames <= 0 && touchesHazard(body, tileAt)) {
      damage(1, from: body.centerX);
    }

    // --- state
    if (state != PlayerState.dead) {
      if (hurtTime > 0) {
        state = PlayerState.hurt;
      } else if (attacking) {
        state = PlayerState.attack;
      } else if (!body.onGround) {
        state = body.vy < 0 ? PlayerState.jump : PlayerState.fall;
      } else {
        state = body.vx.abs() > 5 ? PlayerState.run : PlayerState.idle;
      }
    }
  }

  /// Apply [amount] hearts of damage from a source at x=[from].
  /// Returns true if damage landed (not invulnerable).
  bool damage(int amount, {required double from}) {
    if (iFrames > 0 || state == PlayerState.dead) return false;
    hearts -= amount;
    iFrames = kHurtIFrames;
    hurtTime = 0.25;
    attackTime = 0;
    final dir = body.centerX >= from ? 1 : -1;
    body.vx = dir * kKnockbackSpeed;
    body.vy = -kKnockbackSpeed * 0.6;
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

  void kill() {
    if (state == PlayerState.dead) return;
    hearts = 0;
    state = PlayerState.dead;
    _events.add(PlayerEvent.died);
  }
}
