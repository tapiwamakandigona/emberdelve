// test/thirteenth_fire_test.dart — v0.173.0 The Worldflame.
//
// The ladder grew a thirteenth fire: Worldflame above the Everburn. Veterans
// who long ago banked 3750 marks climb again — and the curve keeps its shape.
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ladder has thirteen fires and the Worldflame tops it', () {
    expect(rankTiers.length, 13);
    final top = rankTiers.last;
    expect(top.id, 'worldflame');
    expect(top.marks, 5450);
    expect(
      top.withArticle,
      'a Worldflame',
      reason: '"You delve as …" must stay grammatical',
    );
  });

  test('the climb keeps accelerating: threshold gaps never shrink', () {
    for (var i = 2; i < rankTiers.length; i++) {
      final gap = rankTiers[i].marks - rankTiers[i - 1].marks;
      final prev = rankTiers[i - 1].marks - rankTiers[i - 2].marks;
      expect(
        gap >= prev,
        isTrue,
        reason: '${rankTiers[i].id} gap $gap under previous $prev',
      );
    }
  });

  test('a Worldflame stands at the top of the ladder', () {
    final m = MetaState()..runsWon = 1817; // 5451 marks: past the new top.
    expect(rankFor(m).id, 'worldflame');
    expect(nextRank(m), isNull, reason: 'nothing above the top tier');
  });
}
