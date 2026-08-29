// test/proven_rules_test.dart — v0.108.0 The Proven Rules.
//
// Two curated provings that keep the weekly's rules standing (Flint,
// Cold Camps), plus the clear-match honesty fix they made load-bearing:
// the rules are part of the proving's name, so a run of the same seed
// with different rules clears nothing, in either direction.
import 'dart:io';

import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
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

  test('the modded provings declare real rules and keep ash_summit last', () {
    for (final id in ['flint_proving', 'cold_proving']) {
      final p = provingById(id)!;
      expect(p.mutators, isNotEmpty);
      for (final m in p.mutators) {
        expect(isKnownMutator(m), isTrue, reason: '$id: $m');
      }
      // The card's rule names resolve (screen joins them into the meta line).
      for (final m in p.mutators) {
        expect(mutatorDef(m).name, isNotEmpty);
      }
    }
    expect(provings.last.id, 'ash_summit', reason: 'the last name stays last');
  });

  group('clear-match honors the rules', () {
    late Directory dir;
    late GameController c;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('proven_rules');
      c = GameController(saveDirOverride: dir.path);
      await c.boot();
    });

    tearDown(() async {
      for (var i = 0; i < 10; i++) {
        try {
          await dir.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    });

    test('winning the exact modded run marks the modded proving', () async {
      final p = provingById('cold_proving')!; // warden normal seed 2 no_rests
      c.startRun(
        character: p.character,
        seed: p.seed,
        difficulty: p.difficulty,
        ascension: p.ascension,
        boons: true, // the screen starts provings with boons on
        mutators: p.mutators,
      );
      driveToTerminal(c);
      expect(c.phase, 'run_won', reason: 'seed 2 no_rests must stay bot-won');
      expect(c.meta.provingsCleared, contains('cold_proving'));
    });

    test('same seed without the rules clears nothing', () async {
      final p = provingById('cold_proving')!;
      c.startRun(
        character: p.character,
        seed: p.seed,
        difficulty: p.difficulty,
        ascension: p.ascension,
      );
      driveToTerminal(c);
      // Whatever the unmodded outcome, the modded proving stays unmarked —
      // and if this unmodded warden run happens to match no OTHER proving,
      // nothing is marked at all.
      expect(c.meta.provingsCleared, isNot(contains('cold_proving')));
    });

    test('modded run of an unmodded proving seed clears nothing', () async {
      final p = provingById('first_flame')!; // kindler easy seed 1, no rules
      c.startRun(
        character: p.character,
        seed: p.seed,
        difficulty: p.difficulty,
        mutators: const ['all_d4'],
      );
      driveToTerminal(c);
      expect(c.meta.provingsCleared, isNot(contains('first_flame')));
    });
  });
}
