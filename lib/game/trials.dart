// lib/game/trials.dart — Today's Trials date picker + goal judge (v0.9.0).
// Pure Dart, no Flutter imports, fully testable.
//
// Studio lesson (docs/improvements/studio-priorities-2026-08-16.md §2): a
// daily whose RULE rotates is a genuine "what's today's?" curiosity hook;
// a daily that only reshuffles the map is the same run every day. Each
// calendar date deterministically carries ONE trial (data/trials.dart) on
// top of the Daily Delve seed — no server, no streaks, no expiry (§Ethics).
//
// SEALED-SIM CONTRACT: sim/daily.dart stays untouched. This module lives in
// the game layer; mutator days ride the existing cmd['mutators'] seam and
// goal days are pure observation over the finished run. The trial is a pure
// function of the DATE, so a resumed daily re-derives it from its saved
// date label — nothing new is persisted.

import '../data/trials.dart';
import '../sim/rng.dart';
import 'run_trace.dart';

export '../data/trials.dart';

/// The one trial declared for [year]-[month]-[day]. Pure: same date ->
/// same trial, on every device, forever. Namespaced apart from the daily
/// and weekly seed domains so the trial rotation never correlates with
/// either seed sequence.
TrialDef trialForDate(int year, int month, int day) {
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  final h = hashDomainString('emberdelve-trial:$year-$m-$d');
  return trialDef(trialsOrder[h % trialsOrder.length]);
}

/// [trialForDate] from a daily key ('YYYY-MM-DD', the dailyKey format —
/// the single label the controller persists for a daily run). Null on a
/// malformed key, so a corrupted save degrades to "no trial", never a throw.
TrialDef? trialForDailyKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return trialForDate(y, m, d);
}

/// Whether a finished run met [trial]'s goal. Pure function over the final
/// run snapshot and the floor trace; mutator days (no goal) and unknown
/// goal ids are simply false — a future goal id handed to an old build
/// pays nothing rather than crashing (forward-compatible, same convention
/// as unknown save keys).
bool trialGoalMet(TrialDef trial, Map<String, Object?> run, RunTrace trace) {
  switch (trial.goalId) {
    case 'gold_at_least':
      return ((run['gold'] as int?) ?? 0) >= trial.goalParam;
    case 'fights_at_least':
      return ((run['fights_won'] as int?) ?? 0) >= trial.goalParam;
    case 'embers_at_least':
      return ((run['embers'] as int?) ?? 0) >= trial.goalParam;
    case 'clean_floors_at_least':
      return trace.marks.where((m) => m == markClean).length >= trial.goalParam;
    // v0.147.0 The Marked Day: the temper arc's first trial. Pure
    // observation of the run's own counter — the sim stays sealed.
    case 'tempers_at_least':
      return ((run['tempers_used'] as int?) ?? 0) >= trial.goalParam;
    // v0.154.0 The Keeper's Day: pure observation of the run's relic
    // list — the sim stays sealed.
    case 'relics_at_least':
      return ((run['relics'] as List?)?.length ?? 0) >= trial.goalParam;
    // v0.156.0 The Deep Day: pure observation of the run's own die
    // records — a deep mark is a custom die whose tier reached 2. Absent
    // tier reads as 1 (the v0.155.0 optional-key save contract), so a
    // pre-deepening save simply counts zero.
    case 'deep_marks_at_least':
      final dice = (run['custom_dice'] as Map?)?.values ?? const [];
      final deep = dice
          .where((d) => ((d as Map)['tier'] as int? ?? 1) >= 2)
          .length;
      return deep >= trial.goalParam;
    default:
      return false;
  }
}
