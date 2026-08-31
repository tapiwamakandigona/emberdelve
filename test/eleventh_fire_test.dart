// test/eleventh_fire_test.dart — v0.161.0 The Eleventh Fire.
//
// The ladder grew again: Firstflame above Mountainheart. Veterans who long
// ago banked 1700 marks climb again — and the curve keeps its shape.
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firstflame holds the eleventh chair', () {
    // v0.166.0 grew the ladder past it; the tier itself is frozen here.
    final top = rankTiers[10];
    expect(top.id, 'firstflame');
    expect(top.marks, 2550);
    expect(
      top.withArticle,
      'a Firstflame',
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

  test('a Mountainheart has a next fire again', () {
    final m = MetaState()..runsWon = 600; // 1800 marks: the old ladder's top.
    expect(rankFor(m).id, 'mountainheart');
    expect(
      nextRank(m)!.id,
      'firstflame',
      reason: 'the veteran plateau is a climb again',
    );
  });

  test('a Firstflame has a next fire again', () {
    final m = MetaState()..runsWon = 900; // 2700 marks: the old ladder's top.
    expect(rankFor(m).id, 'firstflame');
    expect(
      nextRank(m)!.id,
      'everburn',
      reason: 'v0.166.0: the veteran plateau is a climb again',
    );
  });
}
