// lib/game/daily_share.dart — Daily Delve recap + share text (v0.3.4).
// Pure functions, no Flutter imports, fully testable.
//
// Ethics line (spec §Ethics, mirrored from the title-screen comments): the
// daily has NO streaks and NO expiry pressure, so neither string may imply
// either. The share text states a result, honestly, and stops.

/// Local calendar key for a date, e.g. '2026-07-24'. The single formatting
/// authority for daily keys — GameController and the title screen both use
/// it, so the recap can never miss because of a format drift.
String dailyKey(DateTime d) =>
    '${d.year}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// One-line recap for the title screen, shown under the Daily Delve button
/// on the day it was played. Honest and small: a checkmark, the outcome.
String dailyRecapLine({
  required bool won,
  required int floor,
  required int floors,
}) => won
    ? '✓ Played today — the Ember claimed'
    : '✓ Played today — fell on floor $floor of $floors';

/// Day-2 arrival line (retention lane, DEMAND 2026-08-31c focus #1): when
/// yesterday's daily is the profile's last one, the title acknowledges the
/// return and states the one honest fact that matters — today's delve is a
/// different one. Still the single stored record, still no history, no
/// chain counter, no expiry talk (§Ethics): a player arriving on day 2 is
/// told what is TRUE today, never what they owe.
String dailyReturnLine({required bool won, required int floor}) => won
    ? 'Yesterday\u2019s delve fell to you. Today deals a new one.'
    : 'Yesterday you reached floor $floor. Today deals a new delve.';

/// Copyable result for the summary screen (review note #3): Wordle-style,
/// deliberately plain text so it pastes anywhere. States the shared-seed
/// fact instead of a call to action — no streaks, no pressure.
String dailyShareText({
  required String date,
  required bool won,
  required int floor,
  required int floors,
  String grid = '',
  String trial = '',
}) {
  final line = won
      ? '🔥 Claimed the Ember — floor $floors of $floors'
      : '🕯️ Fell on floor $floor of $floors';
  return [
    // v0.9.0: the header carries the day's declared trial name, so a shared
    // result also shares the rule it was played under. No trial, old header.
    trial.isEmpty ? 'Emberdelve Daily $date' : 'Emberdelve Daily $date · $trial',
    // v0.8.0: spoiler-free floor trace (run_trace.dart) — recognizable at a
    // glance, says how it went without revealing what the shared map holds.
    if (grid.isNotEmpty) grid,
    line,
    'One shared delve — same seed for everyone.',
  ].join('\n');
}
