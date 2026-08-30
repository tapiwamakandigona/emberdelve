// test/deep_wardrobe_test.dart — v0.94.0 The Deep Wardrobe charter pins.
//
//   1. ORDER HONESTY: the three new epithets slot BEFORE the Proven — the
//      Provings summit stays the last word on the shelf.
//   2. TARGET HONESTY: the_six_handed's target equals the live roster count,
//      so a future seventh delver can never silently orphan the unlock
//      line's promise (same pin shape as the_proven / provings.length).
//   3. DERIVED UNLOCKS: each new title flips exactly at its banked counter,
//      through the same statValue resolver as the Ledger.
//   4. DYE SHELF: the two new dyes keep the catalog's ascending-price read
//      and are real recolors (non-identity filters), buyable through the
//      one existing purchase path.
//
// Copy sweeps (ethics banned words, coherent ids) are already enforced for
// ALL entries by test/epithets_test.dart and test/attire_test.dart loops.

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/game/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Proven remains last; the new titles sit just before it', () {
    expect(
      epithetsOrder.last,
      'the_proven',
      reason: 'the Provings summit stays the last word — real contract',
    );
    // v0.129.0: the_tempered/the_weathered slotted before the Proven; the
    // wardrobe titles keep their append INDICES (the 'last' pin lesson).
    expect(epithetsOrder.sublist(9, 12), [
      'the_deepdrawn',
      'the_measured',
      'the_six_handed',
    ]);
  });

  test('the_six_handed target equals the live roster count', () {
    expect(epithets['the_six_handed']!.target, characters.length);
    expect(epithets['the_six_handed']!.stat, 'delvers_cleared');
  });

  test('the Deepdrawn flips exactly at the ninth floor', () {
    final c = GameController();
    c.meta.bestFloor = 8;
    expect(c.epithetUnlocked('the_deepdrawn'), isFalse);
    c.meta.bestFloor = 9;
    expect(c.epithetUnlocked('the_deepdrawn'), isTrue);
  });

  test('the Measured flips exactly at a run of five exact ends', () {
    final c = GameController();
    c.meta.bestExactStreak = 4;
    expect(c.epithetUnlocked('the_measured'), isFalse);
    c.meta.bestExactStreak = 5;
    expect(c.epithetUnlocked('the_measured'), isTrue);
  });

  test('the Six-Handed asks a win from every delver, junk keys ignored', () {
    final c = GameController();
    final roster = characters.keys.toList();
    for (final id in roster.sublist(0, roster.length - 1)) {
      c.meta.charWins[id] = 1;
    }
    // A hand-edited junk key can never stand in for the missing delver.
    c.meta.charWins['ghost_delver'] = 99;
    expect(c.epithetUnlocked('the_six_handed'), isFalse);
    c.meta.charWins[roster.last] = 1;
    expect(c.epithetUnlocked('the_six_handed'), isTrue);
  });

  test('new dyes keep the ascending-price shelf and really recolor', () {
    // v0.128.0: forgesoot appended — the contract is the INDEX (append-
    // order stability), not final position (the 'last' pin lesson, third
    // occurrence: tinker v0.118, frostvein v0.126, and now the shelf).
    expect(delverDyesOrder.indexOf('emberheart'), 8);
    expect(delverDyesOrder.indexOf('glowmere'), 9);
    var last = -1;
    for (final id in delverDyesOrder) {
      final d = delverDyes[id]!;
      expect(d.costEmbers, greaterThan(last), reason: id);
      last = d.costEmbers;
    }
    for (final id in ['emberheart', 'glowmere']) {
      final d = delverDyes[id]!;
      expect(
        d.hueDeg != 0 || d.satMul != 1 || d.valMul != 1,
        isTrue,
        reason: '$id must be a real recolor, not the identity',
      );
    }
  });

  test('the new dyes buy through the one existing purchase path', () {
    final c = GameController();
    c.meta.embers = 2000;
    for (final id in ['emberheart', 'glowmere']) {
      expect(c.buyDye(id), isTrue, reason: id);
      expect(c.meta.ownedDyes.contains(id), isTrue, reason: id);
    }
    expect(c.meta.embers, 2000 - 480 - 560);
  });
}
