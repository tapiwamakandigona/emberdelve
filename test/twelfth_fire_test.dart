// test/twelfth_fire_test.dart — v0.166.0 The Everburn.
//
// The ladder grew a twelfth fire: Everburn above Firstflame. Veterans who
// long ago banked 2550 marks climb again — and the curve keeps its shape.
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ladder has twelve fires and the Everburn tops it', () {
    expect(rankTiers.length, 12);
    final top = rankTiers.last;
    expect(top.id, 'everburn');
    expect(top.marks, 3750);
    expect(
      top.withArticle,
      'an Everburn',
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

  test('an Everburn stands at the top of the ladder', () {
    final m = MetaState()..runsWon = 1250; // 3750 marks: exactly the new top.
    expect(rankFor(m).id, 'everburn');
    expect(nextRank(m), isNull, reason: 'nothing above the top tier');
  });
}
