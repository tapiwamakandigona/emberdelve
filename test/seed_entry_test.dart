// test/seed_entry_test.dart — v0.3.4 seed display + entry (review note #5):
//   1. parseSeedInput: numbers round-trip, words hash deterministically,
//      blank returns null, results always land in [1, 2^31-2].
//   2. Summary shows the run seed; tapping copies it.
//   3. 'Delve a seed' starts a run on exactly the entered seed — the whole
//      point: same seed, same delve, on every device.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/game/seed_input.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
    switch (c.phase) {
      case 'boon':
        c.apply({'type': 'choose_boon', 'index': 0});
        break;
      case 'map':
        final m = c.state!['map'] as Map;
        final e = (m['edges'] as Map).cast<String, List>();
        final p = m['position'] as int;
        c.apply({
          'type': 'choose_node',
          'node': (e['$p'] as List).cast<int>().first,
        });
        break;
      case 'player_turn':
        c.apply({'type': 'roll'});
        c.apply({'type': 'end_turn'});
        break;
      case 'reward':
        c.apply({'type': 'choose_reward', 'index': 0});
        break;
      case 'rest':
        c.apply({'type': 'rest'});
        break;
      case 'shop':
        c.apply({'type': 'leave_shop'});
        break;
      case 'event':
        c.apply({'type': 'event_choose', 'option': 1});
        break;
    }
  }
}

void main() {
  test('parseSeedInput: numbers round-trip, words hash, blank is null', () {
    expect(parseSeedInput('12345'), 12345);
    expect(parseSeedInput('  12345  '), 12345, reason: 'whitespace trimmed');
    expect(parseSeedInput(''), isNull);
    expect(parseSeedInput('   '), isNull);
    expect(parseSeedInput('0'), 1, reason: '0 is an LCG fixed point');

    final word = parseSeedInput('emberlord');
    expect(word, parseSeedInput('emberlord'), reason: 'deterministic');
    expect(word, isNot(parseSeedInput('emberlady')));

    for (final s in ['-7', '99999999999999', 'Δice', 'a b c']) {
      final v = parseSeedInput(s)!;
      expect(v, inInclusiveRange(1, 0x7ffffffe), reason: 'input: $s');
    }
  });

  testWidgets('summary shows the seed and tapping copies it', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 424242);
    await pumpFor(tester, 700);
    driveToTerminal(c);
    await pumpFor(tester, 2500);

    final seedLine = find.byKey(const ValueKey('run-seed'));
    expect(seedLine, findsOneWidget);
    // v0.37.0: the summary row now shows the full-challenge Delve Code
    // (seed + delver + difficulty + ascension), and tap copies the code.
    final run = c.state!['run'] as Map;
    final code = encodeDelveCode(
      seed: 424242,
      character: 'kindler',
      difficulty: run['difficulty'] as String,
      ascension: int.parse('${run['ascension'] ?? 0}'),
    )!;
    expect(find.textContaining(code), findsOneWidget);
    await tester.ensureVisible(seedLine);
    await tester.tap(seedLine);
    await pumpFor(tester, 200);
    expect(copied.single, code);
    expect(decodeDelveCode(copied.single as String)!.seed, 424242);
    await pumpFor(tester, 400);
  });

  testWidgets('Delve a seed starts a run on exactly that seed', (tester) async {
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
    await tester.enterText(find.byKey(const ValueKey('seed-field')), '424242');
    await tester.tap(find.byKey(const ValueKey('seed-start')));
    await pumpFor(tester, 700);
    expect(c.phase, 'boon', reason: 'seeded delve opens on the boon pick');
    expect(c.sim!.runSeed, 424242);
    expect(c.dailyDate, isNull, reason: 'a seeded run is not a daily');
    await pumpFor(tester, 400);
  });

  testWidgets('a Delve Code starts the exact challenge it packs', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    final code = encodeDelveCode(
      seed: 424242,
      character: 'gambler',
      difficulty: 'normal',
      ascension: 0,
    )!;
    final entry = find.byKey(const ValueKey('seeded-delve'));
    await tester.scrollUntilVisible(
      entry,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await pumpFor(tester, 400);
    await tester.enterText(
      find.byKey(const ValueKey('seed-field')),
      code.toLowerCase(), // humans type lowercase; the codec tolerates it
    );
    await tester.tap(find.byKey(const ValueKey('seed-start')));
    await pumpFor(tester, 700);
    expect(c.sim!.runSeed, 424242);
    expect((c.state!['run'] as Map)['character'], 'gambler');
    expect((c.state!['run'] as Map)['difficulty'], 'normal');
    await pumpFor(tester, 400);
  });

  testWidgets('a locked-tier Delve Code clamps down, never a paywall', (
    tester,
  ) async {
    final c = GameController(); // fresh meta: hard locked, ascension 0
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);

    final code = encodeDelveCode(
      seed: 777,
      character: 'kindler',
      difficulty: 'hard',
      ascension: 12,
    )!;
    final entry = find.byKey(const ValueKey('seeded-delve'));
    await tester.scrollUntilVisible(
      entry,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await pumpFor(tester, 400);
    await tester.enterText(find.byKey(const ValueKey('seed-field')), code);
    await tester.tap(find.byKey(const ValueKey('seed-start')));
    await pumpFor(tester, 700);
    // The run starts — a friend's code is never a wall — but on the tiers
    // this delver has actually earned (the clampRunParams guarantee).
    expect(c.sim!.runSeed, 777);
    expect((c.state!['run'] as Map)['difficulty'], 'normal');
    expect(int.parse('${(c.state!['run'] as Map)['ascension'] ?? 0}'), 0);
    await pumpFor(tester, 400);
  });
}
