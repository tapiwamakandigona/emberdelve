// game/tuning.dart — ALL game-feel constants live here (spec §3).
// Tests assert the invariants at the bottom; tune freely, keep tests green.

// World scale.
const double kTileSize = 16.0; // logical px per tile
const double kGravity = 1150.0; // px/s^2
const double kMaxFallSpeed = 420.0; // terminal velocity px/s

// Horizontal movement.
const double kRunSpeed = 118.0; // px/s
const double kGroundAccel = 1400.0;
const double kAirAccel = 900.0;
const double kGroundFriction = 1600.0;
// Turnaround assist: extra accel while input opposes current velocity —
// reversing at full run speed snaps in ~0.05s instead of ~0.17s. Touch-first
// games live and die on this (direction changes are the most common input).
const double kTurnAccelMultiplier = 2.0;

// Jumping (feel spec: coyote 0.10s, buffer 0.12s, variable height).
const double kJumpSpeed = 292.0; // initial jump velocity px/s (clears 2 tiles+)
const double kJumpCutMultiplier = 0.45; // vy *= this when jump released early
// Asymmetric gravity (feel research: falls should read snappier than rises —
// 1.5-2.0x is the platformer convention; Celeste additionally halves gravity
// around the apex while jump is held, buying air control without floatiness).
const double kFallGravityMultiplier = 1.6; // gravity scale while vy > 0
const double kApexGravityMultiplier = 0.55; // gravity scale in the apex window
const double kApexHangSpeed = 40.0; // |vy| px/s that counts as "at the apex"
const double kCoyoteTime = 0.10; // s of grace after walking off a ledge
const double kJumpBufferTime = 0.12; // s a jump press is remembered
const int kMaxAirJumps = 1; // double jump (2 with triple-jump special)
const double kAirJumpSpeed = 265.0;
// Ceiling corner correction (Celeste-style forgiveness): a rising jump that
// clips a ceiling lip by up to this many px slides around it instead of
// bonking. Player-only; enemies keep exact collision.
const double kCeilingCornerNudge = 4.0;

// Footsteps: cadence while running on ground. Deliberately quiet +
// alternating samples so it never grates on phone speakers.
const double kFootstepInterval = 0.26; // s between steps at full run

// Roll (DOWN+JUMP on solid ground): a quick commit-dodge. 11-frame sheet.
const double kRollDuration = 0.38; // s locked in the roll
const double kRollSpeed = 190.0; // px/s in facing direction
const double kRollIFrames = 0.28; // s of invulnerability from roll start
const double kRollCooldown = 0.35; // s after the roll ends before the next

// Combat.
const double kAttackBufferTime = 0.15; // s an attack press is remembered
const double kComboWindow = 0.38; // s after a swing in which next chains
const int kComboHits = 3; // 3-hit chain; 3rd hit +50% damage
const double kAttackDuration = 0.22; // s per swing
const double kHitPause = 0.040; // s freeze on connect
const double kHurtIFrames = 1.0; // s invulnerability after taking a hit
const double kKnockbackSpeed = 150.0; // px/s away from damage source
const double kAppleThrowSpeed = 220.0; // px/s, 45deg-ish arc
const int kAppleDamage = 2;
const double kEmberShotSpeed = 120.0; // px/s, Ember Totem spit (dodgeable)

// Camera.
// AKP-1c: 24 -> 32 to give back forward sight lost to the 384x216 zoom
// (fewer tiles visible per screen; hazards must never appear later than ~1s
// of travel time before they need a reaction).
const double kCameraLookAhead = 32.0; // px in facing direction
const double kCameraSmooth = 8.0; // exp smoothing factor
const double kCameraPeekDown = 56.0; // px when holding down

// Player.
const int kBaseMaxHearts = 3;
const int kHeartsHardCap = 5;

// Economy pacing.
const int kCoinValue = 1;
const int kChestCoinsMin = 12;
const int kChestCoinsMax = 30;

/// Perfect-clear bonus: earning all three medals in a single run
/// (finished + all chests + low damage) pays this many extra coins.
/// Paid on every perfect run, not just the first — it rewards mastery,
/// so replaying for a clean run always feels worth it.
const int kPerfectClearBonus = 25;

// Performance budgets (enforced by review, referenced in tests).
const int kMaxLiveParticles = 120;
const int kMaxPooledProjectiles = 16;
