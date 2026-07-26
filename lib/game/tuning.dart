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
// Minimum jump hold: the cut cannot land until the jump has been rising for
// this long. A one-frame tap on a touch button used to leave ~7px of rise —
// less than one 16px tile — so tap-jumps read as dropped inputs. With the
// window a tap clears ~1.5 tiles and a full hold still buys the whole
// 2.3-tile arc, so variable height survives.
const double kMinJumpHold = 0.09;
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
// AKP-2b (owner-confirmed 2026-07-25): AK-style air dash — the dash button
// also fires mid-air: horizontal kRollSpeed burst, gravity suspended for
// the duration, ONE air dash per airborne period (resets on landing).
// Tuning flag kept so it can be A/B'd on-device before the beta.
const bool kAirDashEnabled = true;

// Spells (AKP-4d, owner-confirmed 2026-07-25). One cast per level run.
const double kSpellBurstRadius = 56.0; // px around the player centre
const int kSpellBurstDamage = 4; // + 3s ignite on survivors
const double kSpellVeilSeconds = 3.0; // stone veil immunity window
const int kSpellHealHearts = 2; // hearth light restore (clamped to max)

// Combat.
const double kAttackBufferTime = 0.15; // s an attack press is remembered
const double kComboWindow = 0.38; // s after a swing in which next chains
const int kComboHits = 3; // 3-hit chain; 3rd hit +50% damage
const double kAttackDuration = 0.22; // s per swing
const double kHitPause = 0.040; // s freeze on connect
// AKP-3d: a connect that matters (crit or the 3-hit finisher) freezes longer
// than a plain hit. Apple Knight's combat reads heavy because the heavy beats
// stop the frame; the light ones do not.
const double kHitPauseHeavy = 0.075; // s freeze on crit / combo finisher
const double kHurtIFrames = 1.0; // s invulnerability after taking a hit
const double kKnockbackSpeed = 150.0; // px/s away from damage source
// AKP-6b: hazard tiles (spike/fire pits) eject the player up and along the
// direction of travel instead of the normal shallow knockback, which left
// you inside the pit chain-taking hits. 340 px/s rises ~50px (3 tiles);
// 170 px/s across ~0.6s of airtime clears a 4-tile pit from its lip.
const double kHazardEjectSpeedY = 340.0;
const double kHazardEjectSpeedX = 170.0;
const double kAppleThrowSpeed = 220.0; // px/s, 45deg-ish arc
const int kAppleDamage = 2;
const double kEmberShotSpeed = 120.0; // px/s, Ember Totem spit (dodgeable)

// Camera.
// AKP-1c: 24 -> 32 for the 384x216 zoom, 32 -> 40 for the owner-confirmed
// 352x198 AK-exact zoom (half-width shrank 192 -> 176; +8 look-ahead keeps
// forward sight at 216px ≈ 1.8s of run travel at kRunSpeed 118 — hazards
// must never appear later than ~1s before they need a reaction).
const double kCameraLookAhead = 40.0; // px in facing direction
const double kCameraSmooth = 8.0; // exp smoothing factor
const double kCameraPeekDown = 56.0; // px when holding down

// Game juice (AKP-3, docs/ak-parity-plan.md §3). All small, all capped: the
// Android perf budget and motion-sickness both punish generous FX.
/// Landing squash-and-stretch window (s) and the scale applied at its start.
const double kLandSquashTime = 0.09;
const double kLandSquashScaleX = 1.16;
const double kLandSquashScaleY = 0.84;
/// Player sprite flashes red for this long after taking a hit (the i-frame
/// blink alone reads as "invisible", not as "that hurt").
const double kPlayerHurtFlash = 0.14;
/// Swing arc overlay lifetime (s). One arc per swing, facing-flipped.
const double kSwingArcLife = 0.16;
/// Floating damage numbers: lifetime (s), rise distance (px) and how many may
/// live at once (oldest is dropped past the cap — see kMaxLiveParticles).
const double kDamageNumberLife = 0.55;
const double kDamageNumberRise = 14.0;
const int kMaxDamageNumbers = 8;
/// Camera shake amplitudes (px) per beat, and the decay rate (px/s).
/// Deliberately NOT fired on ordinary hits: constant shake is the fastest way
/// to make a phone game feel cheap and nauseating.
const double kShakeHurt = 3.0; // player took damage
const double kShakeHeavyHit = 2.0; // crit or combo finisher connected
const double kShakeBossSlam = 3.5; // boss phase change / heavy boss attack
const double kShakeBossDeath = 4.5;
const double kShakeWallBreak = 1.5;
const double kShakeMax = 4.5; // hard cap, whatever asks for more
const double kShakeDecay = 16.0; // px/s

// Player.
const int kBaseMaxHearts = 3;
const int kHeartsHardCap = 5;

// Lives & checkpoints (Apple-Knight parity, 2026-07-25 alpha pass).
// Measured problem: a bot playing every shipped level lost all three hearts
// in 4-16s and was thrown back to the level select — the whole run gone.
// AK answers this with lit-campfire checkpoints plus a small pool of lives,
// so a mistake costs a section, never the level. Same model here.
const int kStartingLives = 3; // extra attempts per level run
const double kRespawnIFrames = 2.0; // grace after a checkpoint respawn
/// Enemies this close to a respawn are sent back to their patrol start, so a
/// campfire can never become a meat grinder.
const double kRespawnClearRadius = 96.0;
const double kCheckpointRadius = 14.0; // px from campfire centre to light it

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
