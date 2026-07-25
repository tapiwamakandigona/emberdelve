// meta/daily.dart — Daily Delve: a deterministic daily remix of a World 1
// level. The date alone decides the level and the run seed, so every player
// gets the same remix on the same day. Pure Dart, unit-tested.
//
// Deliberately no dark patterns (spec §7): no streaks, no decay, no expiring
// rewards. Miss a day and nothing is lost — tomorrow is just a new delve.

import '../core/rng.dart';

/// Non-tutorial, non-boss World 1 levels eligible for the daily remix.
const List<String> kDailyPool = ['w1_l2', 'w1_l3', 'w1_l4', 'w1_l5'];

/// Canonical local-date key, e.g. '2026-07-25'.
String dailyKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Deterministic run seed for the date — same for all players, stable
/// across app restarts (derived only from the date string).
int dailySeed(DateTime d) => hashDomainString('daily:${dailyKey(d)}');

/// Which level today's delve remixes (uniform pick from [kDailyPool]).
String dailyLevelId(DateTime d) {
  final rng = Rng.create(dailySeed(d), 'daily-pick');
  return kDailyPool[rng.range(0, kDailyPool.length - 1)];
}
