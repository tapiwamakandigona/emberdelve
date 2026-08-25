// test/epitaph_test.dart — v0.54.0 "The Epitaph": the run's story on the
// Delver's Card. Design doc: docs/improvements/v0.54.0-epitaph-design.md.
//
// Pins:
//   1. epitaphLine is pure and deterministic: exact strings for win/loss ×
//      even/odd seed, epithet worn, killer-less loss, boss-less win.
//   2. Live facts: a seed-1 easy win and a seed-18 easy loss (the pinned
//      share_card pair) carry an epitaph built from banked facts — the
//      card and the full Obituary can never disagree on who/what/where.
//   3. The card renders the epitaph (key 'card-epitaph'), omits it when
//      empty, and survives the WORST realistic string at 1.3x text scale
//      inside its fixed 340×420 frame (the test font wraps wider than
//      shipped fonts — this is the honest overflow gate for the card).
//   4. Copy sweep: every epitaph variant passes the §Ethics banned-word
//      sweep — losses dignified, never mocking.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/obituary.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart' show bossForSeed;
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

const bannedWords = [
  'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
  'bet you', 'only today', "can't", 'loser', //
];

DelverCardFacts factsWith(String epitaph) => DelverCardFacts(
  won: false,
  delverName: 'The Kindler',
  difficulty: 'easy',
  ascension: 0,
  traceGridText: '🟩🟨🟥',
  embers: 12,
  fightsWon: 3,
  seed: 18,
  epitaph: epitaph,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('epitaphLine pins its exact strings, win and loss, both parities', () {
    // Win, odd seed, boss known.
    expect(
      epitaphLine(
        won: true,
        delverName: 'The Kindler',
        epithetTitle: '',
        floor: 9,
        killerName: '',
        bossName: 'Pyre Matriarch',
        seed: 1,
      ),
      'The Kindler walked out with the Ember. '
      'Pyre Matriarch felled at the bottom.',
    );
    // Win, even seed, epithet worn.
    expect(
      epitaphLine(
        won: true,
        delverName: 'The Warden',
        epithetTitle: 'the Unburnt',
        floor: 9,
        killerName: '',
        bossName: 'Hearthless King',
        seed: 4,
      ),
      'The Warden, the Unburnt came back up. '
      'Hearthless King felled at the bottom.',
    );
    // Win with no boss on record stays a single honest sentence.
    expect(
      epitaphLine(
        won: true,
        delverName: 'The Kindler',
        epithetTitle: '',
        floor: 9,
        killerName: '',
        bossName: '',
        seed: 2,
      ),
      'The Kindler came back up.',
    );
    // Loss, even seed, killer named.
    expect(
      epitaphLine(
        won: false,
        delverName: 'The Kindler',
        epithetTitle: '',
        floor: 4,
        killerName: 'Coal-Seam Wyrm',
        bossName: '',
        seed: 18,
      ),
      'Here fell The Kindler — Coal-Seam Wyrm ended the run on floor 4.',
    );
    // Loss, odd seed, legacy record without a killer.
    expect(
      epitaphLine(
        won: false,
        delverName: 'The Gambler',
        epithetTitle: '',
        floor: 6,
        killerName: '',
        bossName: '',
        seed: 3,
      ),
      'The delve took The Gambler on floor 6.',
    );
  });

  test('a won run banks an epitaph naming the seed-chosen boss', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    final f = DelverCardFacts.fromController(c);
    expect(
      f.epitaph,
      'The Kindler walked out with the Ember. '
      '${enemies[bossForSeed(1)]!.name} felled at the bottom.',
    );
    // The card's cut and the full Obituary tell the same story.
    expect(c.delveStoryText, contains(enemies[bossForSeed(1)]!.name));
  });

  test('a lost run banks an epitaph naming the real killer and floor', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    final killer = enemies[c.sim!.enemy?['id'] as String]!.name;
    final f = DelverCardFacts.fromController(c);
    expect(
      f.epitaph,
      'Here fell The Kindler — $killer ended the run '
      'on floor ${c.floorReached}.',
    );
    expect(c.delveStoryText, contains(killer));
  });

  testWidgets('the card shows the epitaph and omits an empty one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Material(
          child: Center(
            child: DelverCard(
              factsWith(
                'Here fell The Kindler — Coal-Seam Wyrm ended the run '
                'on floor 4.',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('card-epitaph')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Material(child: Center(child: DelverCard(factsWith('')))),
      ),
    );
    expect(find.byKey(const ValueKey('card-epitaph')), findsNothing);
  });

  testWidgets('the worst realistic epitaph fits the card at 1.3x scale', (
    tester,
  ) async {
    // Honest worst case: longest delver+epithet, longest enemy names, a
    // full 9-floor trace (maps are 9 layers — 2 grid rows), A20 mode line,
    // a Delve Code line — under the wide test font AND 1.3x device scale
    // (which the card must ignore: it is an exported image). An overflow
    // throws and fails the test; that is the gate the probe can't provide
    // (it never opens the share sheet).
    const worstLoss =
        'The delve took The Gambler, the Well-Oiled — Ashglass Sentinel '
        'ended the run on floor 9.';
    const worstWin =
        'The Gambler, the Well-Oiled walked out with the Ember. '
        'Cinder Hierophant felled at the bottom.';
    for (final (won, epitaph) in [(false, worstLoss), (true, worstWin)]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Material(
              child: Center(
                child: DelverCard(
                  DelverCardFacts(
                    won: won,
                    delverName: 'The Gambler',
                    epithetTitle: 'the Well-Oiled',
                    difficulty: 'normal',
                    ascension: 20,
                    traceGridText: '🟩🟨🟩🟨🟩\n🟨🟩🟨${won ? '🔥' : '🟥'}',
                    embers: 128,
                    fightsWon: 14,
                    seed: 424242,
                    delveCode: 'DELVE-340000A10G',
                    epitaph: epitaph,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('card-epitaph')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'won=$won overflowed');
    }
  });

  test('every epitaph variant passes the ethics sweep', () {
    final variants = <String>[
      for (final won in [true, false])
        for (final seed in [1, 2])
          for (final boss in ['', 'Hearthless King'])
            epitaphLine(
              won: won,
              delverName: 'The Kindler',
              epithetTitle: 'the Unresting',
              floor: 7,
              killerName: boss.isEmpty ? '' : 'Coal-Seam Wyrm',
              bossName: boss,
              seed: seed,
            ),
    ];
    for (final v in variants) {
      for (final word in bannedWords) {
        expect(
          v.toLowerCase().contains(word),
          isFalse,
          reason: 'banned: $word',
        );
      }
    }
  });
}
