// test/winter_proving_test.dart — v0.117.0 The Winter Proving.
//
// The 13th proving: the doubled week's pair (Cold Quarter) as a set delve,
// given to the Peddler — the merchant with nowhere to spend. Seed hunted
// WITH the pair applied.
import 'dart:io';

import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(
      c.sim!,
      character: c.sim!.run?['character'] as String?,
      difficulty: c.sim!.run?['difficulty'] as String? ?? 'normal',
      ascension: c.sim!.run?['ascension'] as int? ?? 0,
    );
    if (cmd == null) break;
    c.apply(cmd);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the winter proving declares the doubled week\'s exact pair', () {
    final p = provingById('winter_proving')!;
    expect(p.character, 'peddler');
    expect(p.difficulty, 'normal');
    expect(
      p.mutators.toSet(),
      doubledWeek.mutators.toSet(),
      reason: 'the proving IS the doubled week, held still',
    );
    for (final m in p.mutators) {
      expect(isKnownMutator(m), isTrue);
      expect(mutatorDef(m).name, isNotEmpty);
    }
    // Order: after cold_proving, before fifth_rung; ash_summit stays last.
    final ids = provings.map((p) => p.id).toList();
    expect(ids.indexOf('winter_proving'), ids.indexOf('cold_proving') + 1);
    expect(ids.indexOf('winter_proving'), lessThan(ids.indexOf('fifth_rung')));
    expect(provings.last.id, 'ash_summit');
  });

  test('winning the exact pair run marks the winter proving', () async {
    final dir = await Directory.systemTemp.createTemp('winter_proving');
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    final p = provingById('winter_proving')!;
    c.startRun(
      character: p.character,
      seed: p.seed,
      difficulty: p.difficulty,
      ascension: p.ascension,
      boons: true, // the screen starts provings with boons on
      mutators: p.mutators,
    );
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 4 pair must stay bot-won');
    expect(c.meta.provingsCleared, contains('winter_proving'));
    // Half the pair is not the pair: the same seed under no_shops alone
    // must NOT mark it (set-equality clear-match, v0.108.0).
    final c2 = GameController(saveDirOverride: dir.path);
    c2.startRun(
      character: p.character,
      seed: p.seed,
      difficulty: p.difficulty,
      boons: true,
      mutators: ['no_shops'],
    );
    driveToTerminal(c2);
    expect(c2.meta.provingsCleared, isNot(contains('winter_proving')));
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('winter proving copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    final p = provingById('winter_proving')!;
    final low = '${p.title} ${p.blurb}'.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
