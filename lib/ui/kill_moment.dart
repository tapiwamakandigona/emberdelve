// lib/ui/kill_moment.dart — experimental polish loop, critic round 1 issue
// C1-01 (+ C0-12 folded in): the run's final kill.
//
// Round-1 plates showed the final-boss kill as a 100% flat #FFE9C4 frame (a
// full-screen opaque white-out held ≥260 ms, ignoring reduced motion) that
// hid the boss's death, then a board that looked live — tray and End turn
// fully lit — with "OVERKILL +3 → NEXT FOE" promising a foe that does not
// exist. This file holds the pure decisions and the stage-scoped flash:
//   • [overkillCallout] — the overkill toast only when a next foe exists;
//   • [BossKillFlash] — a warm radial bloom from the boss, clipped to the
//     stage, peaking at [BossKillFlash.peakAlpha] so the dissolve stays
//     visible; under reduced motion a dim ember tint instead.
// Pinned by test/boss_kill_moment_test.dart. Presentation only (no lib/sim).
import 'package:flutter/widgets.dart';

/// The overkill call-out for a lethal blow's [events], or null when there
/// is none to show. The surplus splashes into the NEXT encounter's foe, so
/// a blow that ends the run (a `run_won` in the same batch, or a boss kill)
/// has no next foe to promise.
String? overkillCallout(
  Iterable<Map<String, Object?>> events, {
  bool bossKill = false,
}) {
  Map<String, Object?>? over;
  var runEnds = bossKill;
  for (final e in events) {
    if (e['type'] == 'overkill') over ??= e;
    if (e['type'] == 'run_won') runEnds = true;
  }
  if (over == null || runEnds) return null;
  return 'OVERKILL +${over['surplus']} → NEXT FOE';
}

/// Opacity of the tray and action zone once the encounter is decided
/// (C1-01 / C2-02: dice included, so none of them reads as live).
const double dimmedControls = 0.35;

/// True when [events] end the encounter (either way): from that frame on
/// the board must stop inviting input.
bool encounterEnds(Iterable<Map<String, Object?>> events) => events.any(
  (e) => e['type'] == 'encounter_won' || e['type'] == 'encounter_lost',
);

/// The boss-kill bloom. Lives inside the stage (the caller clips/positions
/// it to the stage box) and radiates from [focus] (stage coordinates).
class BossKillFlash extends StatelessWidget {
  /// Warm white of the old flash.
  static const Color warm = Color(0xFFFFE9C4);

  /// Dim ember tint used under reduced motion.
  static const Color tint = Color(0xFFF08A2C);

  /// Peak alpha at the bloom's centre (critic acceptance: ≤ 0.45).
  static const double peakAlpha = 0.45;

  /// Flat alpha of the reduced-motion tint.
  static const double tintAlpha = 0.16;

  final bool on;
  final bool reduced;
  final Offset focus;
  final Size stage;

  const BossKillFlash({
    super.key,
    required this.on,
    required this.reduced,
    required this.focus,
    required this.stage,
  });

  /// Fade-in / fade-out durations (reduced: one short ~200 ms tint).
  static Duration fadeFor({required bool on, required bool reduced}) => reduced
      ? const Duration(milliseconds: 100)
      : Duration(milliseconds: on ? 60 : 420);

  @override
  Widget build(BuildContext context) {
    final w = stage.width <= 0 ? 1.0 : stage.width;
    final h = stage.height <= 0 ? 1.0 : stage.height;
    final center = Alignment(
      (focus.dx / w * 2 - 1).clamp(-1.0, 1.0),
      (focus.dy / h * 2 - 1).clamp(-1.0, 1.0),
    );
    final decoration = reduced
        ? BoxDecoration(color: tint.withValues(alpha: tintAlpha))
        : BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: 0.9,
              colors: [
                warm.withValues(alpha: peakAlpha),
                warm.withValues(alpha: peakAlpha * 0.4),
                warm.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 1],
            ),
          );
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: on ? 1.0 : 0.0,
        duration: fadeFor(on: on, reduced: reduced),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: decoration,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
