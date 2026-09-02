// test/widened_trials_test.dart — v0.180.0 "The Widened Rotation", daily side.
//
// Pins: three new mutator days exist and name sim-known ids; dates before
// 2026-09-14 hash over the first eleven trials exactly as v0.156.0 did;
// from that date the full catalog is dealt; the morrow line never lies
// across the seam.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:emberdelve/sim/rng.dart';

void main() {
  test('the three new days are mutator days on known ids', () {
    for (final id in ['cold_camps_day', 'lean_road_day', 'hard_march_day']) {
      final t = trials[id]!;
      expect(t.mutators, isNotEmpty);
      for (final m in t.mutators) {
        expect(isKnownMutator(m), isTrue, reason: '$id names $m');
      }
      expect(t.goalId, '');
    }
    expect(trials['lean_road_day']!.mutators, ['no_shops', 'short_road']);
    expect(trials['hard_march_day']!.mutators, ['no_rests', 'short_road']);
    expect(trials['cold_camps_day']!.mutators, ['no_rests']);
    expect(trialsOrder.sublist(legacyTrialCount), [
      'cold_camps_day',
      'lean_road_day',
      'hard_march_day',
    ]);
  });

  test('before the anchor: the eleven-trial hash is unchanged', () {
    var d = DateTime(2026, 1, 1);
    final anchor = DateTime(2026, 9, 14);
    while (d.isBefore(anchor)) {
      final key =
          'emberdelve-trial:${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final legacy = trialsOrder[hashDomainString(key) % legacyTrialCount];
      expect(trialForDate(d.year, d.month, d.day).id, legacy);
      expect(
        trialsOrder.indexOf(trialForDate(d.year, d.month, d.day).id),
        lessThan(legacyTrialCount),
      );
      d = d.add(const Duration(days: 1));
    }
  });

  test('from the anchor: the whole catalog is dealt', () {
    final seen = <String>{};
    var d = DateTime(2026, 9, 14);
    for (var i = 0; i < 400; i++) {
      seen.add(trialForDate(d.year, d.month, d.day).id);
      d = d.add(const Duration(days: 1));
    }
    expect(seen, containsAll(trialsOrder));
  });

  test('the morrow line is truthful across the seam', () {
    // 13 Sep's "tomorrow" is 14 Sep, computed by the widened rule — the
    // same rule 14 Sep itself uses. No stored promise can break.
    final morrow = trialForMorrow(DateTime(2026, 9, 13, 20));
    expect(morrow.id, trialForDate(2026, 9, 14).id);
    // And 12 Sep's tomorrow (13 Sep) is still the legacy pick.
    expect(
      trialForMorrow(DateTime(2026, 9, 12, 20)).id,
      trialForDate(2026, 9, 13).id,
    );
    expect(
      trialsOrder.indexOf(trialForDate(2026, 9, 13).id),
      lessThan(legacyTrialCount),
    );
  });
}
