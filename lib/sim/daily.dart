// sim/daily.dart — daily-seed helper (v4).
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random,
// and deliberately no DateTime.now() — the CALLER supplies the date, so this
// stays a pure function and everyone playing "today's run" gets the same seed.

import 'rng.dart';

/// Deterministic seed for the daily run of [year]-[month]-[day]. The caller
/// chooses the calendar convention; the shipped controller passes the
/// device's LOCAL date (owner decision v0.3.0 — see docs/m4-sim-contract.md).
/// Pure: same date -> same seed, on every device. Result in [1, 2^31-2].
int dailySeed(int year, int month, int day) {
  assert(month >= 1 && month <= 12, 'dailySeed: bad month');
  assert(day >= 1 && day <= 31, 'dailySeed: bad day');
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  var seed = hashDomainString('emberdelve-daily:$year-$m-$d');
  if (seed == 0) seed = 1; // 0 is a fixed point of the LCG
  return seed;
}

/// Deterministic seed for the Weekly Delve of a given Monday-aligned week
/// index (see game/weekly.dart for the date→index math). Same week index ->
/// same seed on every device, forever. Result in [1, 2^31-2].
///
/// Namespaced apart from daily/custom seeds so a week and a day can never
/// collide onto the same delve. Pure, DateTime-free (the caller supplies the
/// index) — the sim stays a pure function, exactly like [dailySeed].
int weeklySeed(int weekIndex) {
  var seed = hashDomainString('emberdelve-weekly:$weekIndex');
  if (seed == 0) seed = 1; // 0 is a fixed point of the LCG
  return seed;
}
