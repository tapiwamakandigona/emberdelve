// lib/meta/review_service.dart — the single gate for the Play In-App Review
// prompt (REVENUE ASK #1, docs/launch/MARKETING-SYNC.md 2026-08-23). Same
// architecture as PlayGamesService/TelemetryService: this class is
// deliberately free of plugin imports so it stays unit-testable headless.
// main.dart wires the real in_app_review backend in on Android; everywhere
// else (tests, web, desktop) every call is a silent no-op.
//
// Charter (§Ethics + Play policy):
//   • ONE quiet ask per profile, ever. `meta.reviewAsked` is stamped the
//     moment we REQUEST the flow — whether Play actually shows the dialog is
//     its own throttled decision and we never build UI around it, retry, or
//     nag. Version bumps do not reset the flag; cloud merge ORs it so a
//     second device never re-asks.
//   • Asked only at a moment of earned pride, never mid-run: right after the
//     player banks their SECOND (or later) run win, banks a WON daily/weekly
//     delve, or CLIMBS TO SPARKTENDER OR ABOVE. A first win can still be
//     tour-adjacent, so it never triggers the ask on its own.
//   • v0.7.0 REACHABILITY FIX: the win-only gate above was effectively dead
//     code in the wild. Winning a delve is rare by design, and requiring a
//     SECOND win meant that on 2026-08-31, with 54 device acquisitions and
//     21 monthly actives, the store listing still showed NO public rating at
//     all — the single biggest trust penalty on the page. A rank climb is
//     the same kind of earned pride but is actually reachable without a win:
//     marks accrue from foes met, foes felled and codex entries. We ask on
//     the climb to Sparktender (24 marks) rather than Tinderhand (8), so the
//     ask still lands on real investment (several runs) and never on a
//     first-run fluke.
//   • v0.180.0 (directive 2026-09-02d, R10): never at the end of a
//     profile's FIRST run. docs/research/r10-review-prompt-path.md showed
//     both the won-daily route and the Sparktender route could fire after
//     run one (a strong first clear banks 24+ marks about one time in six);
//     a first session is a good run but a thin opinion. `runsPlayed >= 2`
//     (banked before the ask, abandons included) moves every route behind
//     at least one earlier delve.
//   • Never while a Guided Delve beat is on screen. (The tour lives in the
//     first fight and ends by completion or SKIP, so by bank time it is
//     inactive; there is no separate tour-version check — see R10 §1.)
//   • No incentives, no "only if you like it" pre-filtering, no custom
//     rating UI — just the official API, once (Play policy).
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'meta.dart';

/// Requests the platform's in-app review flow. May silently no-op (Play
/// throttling) — the caller must not care.
typedef ReviewRequestBackend = Future<void> Function();

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  /// Wired in main.dart on Android; null everywhere else (silent no-op).
  ReviewRequestBackend? backend;

  /// Marks threshold the player must have just CLIMBED INTO for a rank-up to
  /// count as "earned pride". 24 is Sparktender (data/ranks.dart); the tier
  /// below it, Tinderhand at 8, is reachable inside a single first run, which
  /// is too early to have an opinion worth asking for.
  static const int rankAskFloorMarks = 24;

  /// Runs banked (this one included) before ANY route may ask. Two means
  /// "not the first run": the player has come back at least once.
  static const int minRunsPlayed = 2;

  /// Pure eligibility — the whole charter in one testable expression.
  /// [wonThisRun] is whether the run just banked ended in `run_won`;
  /// [wonDailyOrWeekly] is whether that run was a daily/weekly AND won;
  /// [rankedUpToMarks] is the marks threshold of the tier the player just
  /// climbed INTO on this bank, or null when this bank was not a rank-up;
  /// [tourActive] is whether a Guided Delve beat is currently running.
  static bool eligible(
    MetaState meta, {
    required bool wonThisRun,
    required bool wonDailyOrWeekly,
    required bool tourActive,
    int? rankedUpToMarks,
  }) {
    if (meta.reviewAsked || tourActive) return false;
    // v0.180.0: never at the end of the first run, on any route.
    if (meta.runsPlayed < minRunsPlayed) return false;
    // "Earned pride", in the three shapes it actually takes:
    //   a 2nd+ win, any won daily/weekly (those already require a finished,
    //   won run by construction in _bankRun), or a climb into Sparktender+.
    if ((wonThisRun && meta.runsWon >= 2) || wonDailyOrWeekly) return true;
    return rankedUpToMarks != null && rankedUpToMarks >= rankAskFloorMarks;
  }

  /// Called once per banked run from GameController._bankRun. Stamps
  /// [MetaState.reviewAsked] and asks the backend; the CALLER persists meta
  /// (it saves right after banking anyway, so the stamp always lands).
  /// Returns true when the ask fired (for the caller's save bookkeeping).
  bool maybeAsk(
    MetaState meta, {
    required bool wonThisRun,
    required bool wonDailyOrWeekly,
    required bool tourActive,
    int? rankedUpToMarks,
  }) {
    if (!eligible(
      meta,
      wonThisRun: wonThisRun,
      wonDailyOrWeekly: wonDailyOrWeekly,
      tourActive: tourActive,
      rankedUpToMarks: rankedUpToMarks,
    )) {
      return false;
    }
    meta.reviewAsked = true;
    final b = backend;
    if (b != null) {
      // Fire-and-forget: the summary screen is already up; the review sheet
      // floats over it when Play decides to show it. Failures are silent —
      // the flag stays stamped either way (one ask means one attempt).
      unawaited(
        b().catchError((Object e) {
          debugPrint('review request failed: $e');
        }),
      );
    }
    return true;
  }
}
