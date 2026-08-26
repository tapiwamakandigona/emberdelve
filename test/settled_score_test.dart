// test/settled_score_test.dart — v0.79.0 The Settled Score.
//
// Felling the reigning old foe settles its score: one gold summary line
// (key 'settled-score'), once per foe, EVER — meta.settledFoes gates the
// once, persists, and never reopens (§Ethics: a payoff, not a treadmill).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/ui/screens.dart' show settledScoreLine;

void fell(GameController c, String enemy) {
  c.recordCombatStats([
    {'type': 'encounter_started', 'enemy': enemy},
  ]);
  c.recordCombatStats([
    {'type': 'encounter_won', 'turns': 3},
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ed_settled_score');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() async {
    await MetaStore.save(MetaState());
    MetaStore.dirOverride = null;
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('felling the reigning old foe settles the score, once ever', () {
    final c = GameController(saveDirOverride: dir.path);
    c.meta.enemyFellTo.addAll({'soot_shade': 4, 'ash_rat': 2});
    fell(c, 'soot_shade');
    expect(c.pendingSettledFoe, 'soot_shade');
    expect(c.meta.settledFoes, contains('soot_shade'));
    expect(settledScoreLine(c), 'The score with the Soot Shade is settled.');

    // The once: a later felling of the same foe stays quiet.
    c.pendingSettledFoe = null;
    fell(c, 'soot_shade');
    expect(c.pendingSettledFoe, isNull);
    expect(settledScoreLine(c), isNull);
  });

  test('no foe, no score: below threshold or wrong enemy stays quiet', () {
    final c = GameController(saveDirOverride: dir.path);
    // One fall is bad luck, not a foe.
    c.meta.enemyFellTo['soot_shade'] = 1;
    fell(c, 'soot_shade');
    expect(c.pendingSettledFoe, isNull);

    // A real foe exists, but the run felled someone else.
    c.meta.enemyFellTo['soot_shade'] = 4;
    fell(c, 'ash_rat');
    expect(c.pendingSettledFoe, isNull);
    expect(c.meta.settledFoes, isEmpty);
  });

  test('settledFoes persists through JSON and merges as a union', () {
    final m = MetaState();
    m.settledFoes.addAll({'wick_widow', 'ash_rat'});
    final back = MetaState.fromJson(
      (m.toJson()..removeWhere((k, v) => v == null)).cast<String, dynamic>(),
    );
    expect(back.settledFoes, {'ash_rat', 'wick_widow'});
    expect(MetaState.fromJson({}).settledFoes, isEmpty);

    final cloud = MetaState();
    cloud.settledFoes.add('soot_shade');
    final merged = mergeMetaStates(m, cloud);
    expect(merged.settledFoes, {'ash_rat', 'soot_shade', 'wick_widow'});
  });

  test('the line never names a ghost', () {
    final c = GameController(saveDirOverride: dir.path);
    c.pendingSettledFoe = 'gone_forever';
    expect(settledScoreLine(c), isNull);
  });
}
