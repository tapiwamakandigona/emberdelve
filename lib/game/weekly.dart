// lib/game/weekly.dart — Weekly Delve schedule, modifier pick, and recap
// strings (P3). Pure functions, no Flutter imports, fully testable.
//
// A Weekly Delve is a shared-seed challenge that rotates every 7 days and
// carries a declared rule: ONE modifier (data/mutators.dart) for most weeks,
// and — one week per cycle (v0.111.0 The Doubled Week) — a declared, named
// PAIR. Like the Daily Delve it has NO streaks and NO expiry pressure (spec
// §Ethics): a missed week is simply a missed week, so none of the strings
// below may imply otherwise.
//
// Week math is Monday-aligned and DateTime-free at the seed boundary: the
// sim's weeklySeed(int) takes a plain integer index, and this file is the one
// authority that turns a calendar date into that index (and back into the
// Monday date for the label). Same week -> same index -> same delve, on every
// device, forever.

import '../data/mutators.dart';

/// Days since the Unix epoch (1970-01-01) for a proleptic-Gregorian date.
/// Pure integer math (Howard Hinnant's days_from_civil), so it needs no
/// DateTime and never drifts with the local clock/zone.
int _epochDayFromCivil(int year, int month, int day) {
  final y = month <= 2 ? year - 1 : year;
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yoe = y - era * 400; // [0, 399]
  final doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) ~/ 5 + day - 1;
  final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy; // [0, 146096]
  return era * 146097 + doe - 719468;
}

/// Inverse of [_epochDayFromCivil]: an epoch day back to (year, month, day).
List<int> _civilFromEpochDay(int z) {
  z += 719468;
  final era = (z >= 0 ? z : z - 146096) ~/ 146097;
  final doe = z - era * 146097; // [0, 146096]
  final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
  final y = yoe + era * 400;
  final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100); // [0, 365]
  final mp = (5 * doy + 2) ~/ 153; // [0, 11]
  final d = doy - (153 * mp + 2) ~/ 5 + 1; // [1, 31]
  final m = mp < 10 ? mp + 3 : mp - 9; // [1, 12]
  return [m <= 2 ? y + 1 : y, m, d];
}

/// Monday-aligned week index for a date. All seven days Mon–Sun of the same
/// week share one index; consecutive weeks differ by one. The epoch day 0
/// (1970-01-01) was a Thursday, so +3 shifts the week boundary back to that
/// week's Monday before the floor-divide.
int weekIndex(int year, int month, int day) =>
    (_epochDayFromCivil(year, month, day) + 3) ~/ 7;

/// Convenience over [weekIndex] for a local [DateTime].
int weekIndexForDate(DateTime d) => weekIndex(d.year, d.month, d.day);

/// The Monday date `[y,m,d]` that opens the week with the given [index]. Used
/// for the `Week of <date>` label so it always names a real Monday.
List<int> mondayOfWeek(int index) => _civilFromEpochDay(index * 7 - 3);

/// Human key for a week, e.g. 'Week of 2026-08-10' (always a Monday). The
/// single formatting authority so a recap can never miss on a format drift.
String weeklyKey(int index) {
  final md = mondayOfWeek(index);
  final m = md[1].toString().padLeft(2, '0');
  final d = md[2].toString().padLeft(2, '0');
  return 'Week of ${md[0]}-$m-$d';
}

/// A named weekly rule: the singles read name and blurb straight from the
/// mutator catalog (a rename there can never lie here); the doubled slot
/// authors its own, because a pair deserves one name on the card.
class WeeklyRuleDef {
  final String name;
  final String blurb;
  final List<String> mutators;
  const WeeklyRuleDef(this.name, this.blurb, this.mutators);
}

/// The Doubled Week (v0.111.0): the one composed slot in the rotation.
/// Pair vetted by bot sweep before shipping — see the release notes.
const WeeklyRuleDef doubledWeek = WeeklyRuleDef(
  'Cold Quarter',
  'No shops and no rests \u2014 every camp is a fight, gold buys nothing, '
      'and healing comes only from events and what you carry.',
  ['no_shops', 'no_rests'],
);

/// v0.127.0 The Full Rotation: the canonical banked form of a weekly rule
/// label — ids sorted and '+'-joined, so 'no_rests+no_shops' and
/// 'no_shops+no_rests' are one rule. The legal set is derived from the
/// live rotation: junk labels from a hand-edited save can never count.
String canonicalRuleLabel(String label) => (label.split('+')..sort()).join('+');

/// Every label the current rotation can actually deal, canonicalized.
Set<String> legalRuleLabels() => {
  for (final id in mutatorsOrder) id,
  canonicalRuleLabel(doubledWeek.mutators.join('+')),
};

/// The rule declared for a given week: the singles in [mutatorsOrder], then
/// [doubledWeek] closes the cycle. Deterministic pure function of the week
/// index, so every player sees the same rule for the same week and the
/// rotation is stable across devices and reboots.
WeeklyRuleDef weeklyRuleFor(int index) {
  // Non-negative modulo (week indices are positive for any real date, but
  // stay total anyway rather than trust the caller).
  final n = mutatorsOrder.length + 1;
  final i = ((index % n) + n) % n;
  if (i == n - 1) return doubledWeek;
  final m = mutatorDef(mutatorsOrder[i]);
  return WeeklyRuleDef(m.name, m.blurb, [m.id]);
}

/// Display name for a stored weekly rule label — single mutator ids as-is
/// from the catalog, '+'-joined pairs by their authored name when they match
/// the doubled slot, catalog names joined otherwise. Total: unknown input
/// falls back to 'Delve' rather than throwing at a save from the future.
String weeklyRuleName(String stored) {
  final ids = stored.split('+');
  if (ids.length == 1) {
    return isKnownMutator(stored) ? mutatorDef(stored).name : 'Delve';
  }
  if (ids.toSet().length == doubledWeek.mutators.toSet().length &&
      ids.toSet().containsAll(doubledWeek.mutators)) {
    return doubledWeek.name;
  }
  final known = [
    for (final id in ids)
      if (isKnownMutator(id)) mutatorDef(id).name,
  ];
  return known.isEmpty ? 'Delve' : known.join(' + ');
}

/// One-line recap under the title-screen Weekly Delve button, shown once the
/// current week has been finished. Honest and small — an outcome, no streak.
String weeklyRecapLine({
  required bool won,
  required int floor,
  required int floors,
}) => won
    ? '✓ Cleared this week — the Ember claimed'
    : '✓ Played this week — fell on floor $floor of $floors';

/// Copyable result for the summary screen: states the shared-seed fact and
/// the declared modifier, then stops. No call to action, no pressure.
String weeklyShareText({
  required int index,
  required String mutatorId,
  required bool won,
  required int floor,
  required int floors,
  String grid = '',
}) {
  final name = weeklyRuleName(mutatorId);
  final line = won
      ? '🔥 Claimed the Ember — floor $floors of $floors'
      : '🕯️ Fell on floor $floor of $floors';
  return [
    'Emberdelve Weekly — ${weeklyKey(index)}',
    // v0.8.0: spoiler-free floor trace (run_trace.dart), same charter as the
    // daily's — states how it went, never what the shared map holds.
    if (grid.isNotEmpty) grid,
    '$name · $line',
    'One shared delve — same seed and modifier for everyone.',
  ].join('\n');
}

/// v0.109.0 The Coming Rule: next Monday's declared modifier, stated as a
/// fact for players who already played this week. Pure over the rotation —
/// the same appointment for everyone, no countdown, no pressure (§Ethics).
String comingRuleLine(int thisWeekIndex) =>
    'Next Monday: ${weeklyRuleFor(thisWeekIndex + 1).name}';
