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
//     player banks their SECOND (or later) run win, or banks a WON
//     daily/weekly delve. A first win can still be tour-adjacent, so it
//     never triggers the ask on its own.
//   • Never while the Guided Delve tour is running, and never on a profile
//     that hasn't finished the tour version it was shown.
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

  /// Pure eligibility — the whole charter in one testable expression.
  /// [wonThisRun] is whether the run just banked ended in `run_won`;
  /// [wonDailyOrWeekly] is whether that run was a daily/weekly AND won;
  /// [tourActive] is whether a Guided Delve beat is currently running.
  static bool eligible(
    MetaState meta, {
    required bool wonThisRun,
    required bool wonDailyOrWeekly,
    required bool tourActive,
  }) {
    if (meta.reviewAsked || tourActive) return false;
    // "Earned pride": a 2nd+ win, or any won daily/weekly (those already
    // require a finished, won run by construction in _bankRun).
    return (wonThisRun && meta.runsWon >= 2) || wonDailyOrWeekly;
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
  }) {
    if (!eligible(
      meta,
      wonThisRun: wonThisRun,
      wonDailyOrWeekly: wonDailyOrWeekly,
      tourActive: tourActive,
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
