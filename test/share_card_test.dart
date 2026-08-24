// test/share_card_test.dart — v0.34.0 "The Delver's Card": the shareable
// image summary. Design doc: docs/improvements/v0.34.0-delvers-card-design.md.
//
// Pins:
//   1. Facts honesty: a seed-1 easy win builds a WIN card with the real
//      embers/fights/seed; a seed-13 easy loss builds a LOSS card — loss
//      cards are first-class (§Ethics honesty).
//   2. Copy sweep: every string the card or its fallback text can emit
//      passes the banned-word sweep.
//   3. Summary → sheet: the 'Share this delve' button exists on BOTH
//      terminal screens and opens the preview (card + Share/Close).
//   4. Degradation: in a headless test there is no share plugin — tapping
//      Share must land the plain-text summary on the clipboard, never crash.
//
// Seeds: 1 wins on easy, 13 loses on easy (kindler, boons) — the same
// pinned pair rung_open_test and gramophone_test use.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 4000, isTrue, reason: 'bot run failed to terminate');
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

const bannedWords = [
  'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
  'bet you', 'only today', "can't", 'loser', //
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a won run builds an honest win card', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    final f = DelverCardFacts.fromController(c);
    expect(f.won, isTrue);
    expect(f.delverName, 'The Kindler');
    expect(f.modeLine, 'Easy');
    expect(f.seed, 1);
    final run = c.state!['run'] as Map;
    expect(f.embers, run['embers']);
    expect(f.fightsWon, run['fights_won']);
    expect(f.traceGridText, isNotEmpty);
  });

  test('a lost run builds an honest loss card (loss is first-class)', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 13, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    final f = DelverCardFacts.fromController(c);
    expect(f.won, isFalse);
    expect(f.seed, 13);
  });

  test('ascension shows on the mode line only when climbed', () {
    const base = DelverCardFacts(
      won: true,
      delverName: 'Kindler',
      difficulty: 'hard',
      ascension: 0,
      traceGridText: '',
      embers: 1,
      fightsWon: 1,
      seed: 7,
    );
    expect(base.modeLine, 'Hard');
    const climbed = DelverCardFacts(
      won: true,
      delverName: 'Kindler',
      difficulty: 'hard',
      ascension: 3,
      traceGridText: '',
      embers: 1,
      fightsWon: 1,
      seed: 7,
    );
    expect(climbed.modeLine, 'Hard · Ascension 3');
  });

  testWidgets('card copy passes the ethics sweep, win and loss', (
    tester,
  ) async {
    for (final won in [true, false]) {
      final facts = DelverCardFacts(
        won: won,
        delverName: 'Kindler',
        difficulty: 'easy',
        ascension: 0,
        traceGridText: '🔥🔥🕯️',
        embers: 42,
        fightsWon: 9,
        seed: 1234,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEmberTheme(),
          home: Material(child: Center(child: DelverCard(facts))),
        ),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join('\n');
      for (final word in bannedWords) {
        expect(texts.contains(word), isFalse, reason: 'banned: $word');
      }
      expect(texts, contains('tsorostudios.itch.io/emberdelve'));
    }
  });

  testWidgets('summary offers the card on a win and the sheet previews it', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final btn = find.byKey(const ValueKey('share-delve-card'));
    await tester.scrollUntilVisible(btn, 200);
    await tester.tap(btn);
    await pumpFor(tester, 600);
    expect(find.byType(DelverCard), findsOneWidget);
    expect(find.text('The Ember is yours'), findsNWidgets(2)); // screen + card
    expect(find.byKey(const ValueKey('card-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('card-close')));
    await pumpFor(tester, 600);
    expect(find.byType(DelverCard), findsNothing);
  });

  testWidgets('headless share degrades to a clipboard copy, never a crash', (
    tester,
  ) async {
    String? clipped;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipped = (call.arguments as Map)['text'] as String?;
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
    c.startRun(character: 'kindler', seed: 13, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    await pumpFor(tester, 2500);

    final btn = find.byKey(const ValueKey('share-delve-card'));
    await tester.scrollUntilVisible(btn, 200);
    await tester.tap(btn);
    await pumpFor(tester, 600);
    await tester.tap(find.byKey(const ValueKey('card-share')));
    // toImage/toByteData complete on the real event loop — fake-async pumps
    // alone never resolve them (the runAsync lesson, see gramophone plates).
    for (var i = 0; i < 10 && clipped == null; i++) {
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(clipped, isNotNull, reason: 'fallback must copy the summary');
    // v0.37.0: the fallback carries the full-challenge Delve Code instead
    // of the bare seed — it must decode back to this exact run.
    final codeMatch = RegExp(
      r'DELVE-[0-9A-Z]{10}',
    ).firstMatch(clipped!)!.group(0)!;
    final challenge = decodeDelveCode(codeMatch)!;
    expect(challenge.seed, 13);
    expect(challenge.character, 'kindler');
    expect(clipped, contains('the dark claimed me'));
    expect(clipped, contains('tsorostudios.itch.io/emberdelve'));
    // Sweep the degraded artifact too.
    for (final word in bannedWords) {
      expect(clipped!.toLowerCase().contains(word), isFalse);
    }
  });
}
