// test/rumor_test.dart — The Rumor (v0.53.0): pre-delve boss telegraph.
//   1. rumorForSeed derives from bossForSeed — the line names EXACTLY the
//      boss the seed maps to, on several seeds (never an invented foe).
//   2. The boon pick (the run-start panel) shows the run's rumor.
//   3. The "Delve a seed" dialog previews the rumor live: for a typed seed,
//      for a pasted Delve Code (the code's own seed, not the field text),
//      and shows nothing on a blank field.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/game/rumor.dart';
import 'package:emberdelve/game/seed_input.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  test('rumorForSeed names exactly the boss bossForSeed chose', () {
    for (final seed in [1, 2, 131, 424242, 20260723, 0x7ffffffe]) {
      final boss = enemies[bossForSeed(seed)]!;
      expect(boss.boss, isTrue, reason: 'seed $seed maps to a boss');
      expect(
        rumorForSeed(seed),
        'Rumor has it the ${boss.name} waits at the bottom.',
        reason: 'seed $seed',
      );
    }
    // Different bosses produce different rumors (sanity: the line is not
    // constant — seeds 0..7 cover all eight bosses, % 8 cycle).
    final lines = {for (var s = 0; s < 8; s++) rumorForSeed(s)};
    expect(lines.length, 8);
  });

  testWidgets('the boon pick shows the run\'s rumor', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    c.startRun(character: 'kindler', boons: true, seed: 424242);
    await pumpFor(tester, 700);
    expect(c.phase, 'boon');
    final line = find.byKey(const ValueKey('rumor-line'));
    expect(line, findsOneWidget);
    expect(
      (tester.widget<Text>(line)).data,
      rumorForSeed(424242),
      reason: 'the line is the pure rumor for THIS run\'s seed',
    );
    await pumpFor(tester, 400);
  });

  testWidgets('Delve a seed previews the rumor live', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    final entry = find.byKey(const ValueKey('seeded-delve'));
    await tester.scrollUntilVisible(
      entry,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await pumpFor(tester, 400);

    // Blank field: no rumor yet.
    expect(find.byKey(const ValueKey('rumor-preview')), findsNothing);

    // A typed seed previews its rumor.
    await tester.enterText(find.byKey(const ValueKey('seed-field')), '424242');
    await pumpFor(tester, 200);
    var preview = find.byKey(const ValueKey('rumor-preview'));
    expect(preview, findsOneWidget);
    expect(tester.widget<Text>(preview).data, rumorForSeed(424242));

    // A word hashes to a seed — same rumor rule.
    await tester.enterText(find.byKey(const ValueKey('seed-field')), 'ember');
    await pumpFor(tester, 200);
    preview = find.byKey(const ValueKey('rumor-preview'));
    expect(
      tester.widget<Text>(preview).data,
      rumorForSeed(parseSeedInput('ember')!),
    );

    // A Delve Code previews the CODE's seed (not the raw field text).
    final code = encodeDelveCode(
      seed: 131,
      character: 'tinker',
      difficulty: 'normal',
      ascension: 0,
    )!;
    await tester.enterText(find.byKey(const ValueKey('seed-field')), code);
    await pumpFor(tester, 200);
    preview = find.byKey(const ValueKey('rumor-preview'));
    expect(tester.widget<Text>(preview).data, rumorForSeed(131));

    // Clearing the field clears the rumor.
    await tester.enterText(find.byKey(const ValueKey('seed-field')), '');
    await pumpFor(tester, 200);
    expect(find.byKey(const ValueKey('rumor-preview')), findsNothing);
    await pumpFor(tester, 400);
  });
}
