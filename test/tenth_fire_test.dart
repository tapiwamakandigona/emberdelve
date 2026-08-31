// test/tenth_fire_test.dart — v0.149.0 The Tenth Fire.
//
// The ladder grew: Mountainheart above Deepfire Sovereign. Veterans who
// long ago banked 1100 marks climb again — and the curve keeps its shape.
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mountainheart is the tenth fire', () {
    // v0.161.0: the .last / length pins moved to eleventh_fire_test.dart —
    // this test now pins the TENTH rung itself, which must never move.
    final tenth = rankTiers[9];
    expect(tenth.id, 'mountainheart');
    expect(tenth.marks, 1700);
    expect(
      tenth.withArticle,
      'a Mountainheart',
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

  test('a Sovereign has a next fire again', () {
    final m = MetaState()..runsWon = 400; // 1200 marks: the old ladder's top.
    expect(rankFor(m).id, 'deepfire_sovereign');
    expect(
      nextRank(m)!.id,
      'mountainheart',
      reason: 'the veteran plateau is a climb again',
    );
  });
}
