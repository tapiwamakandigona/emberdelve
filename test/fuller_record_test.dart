// test/fuller_record_test.dart — v0.57.0 "The Fuller Record": run records
// bank what the remembered card (v0.56.0) had to omit — fights won, the
// floor trace (compact codec), and the worn epithet — so cards built off
// NEW records regain full fidelity while old records keep degrading by
// omission. Design doc: docs/improvements/v0.57.0-lead-scout.md.
//
// Pins:
//   1. Compact codec: toCompact/fromCompact roundtrip exactly; unknown
//      characters are dropped, never guessed; the rebuilt trace paints the
//      terminal cell from the outcome the record's own result supplies.
//   2. Banking: a bot-played win and loss each land a record whose fights
//      equals the sim's own count, whose trace decodes to the live trace's
//      marks, and whose epithet key appears ONLY when one is worn.
//   3. fromRecord fidelity: fuller keys bring back the fights figure
//      (fightsKnown true), the grid, and the worn title in BOTH the name
//      line and the epitaph. Absent keys keep the v0.56.0 omissions.
//   4. The fixed 340x480 canvas survives the new worst case: longest
//      name+epithet form, 2-row trace, fights line, two-clause epitaph.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

/// Bot-play [c] to a terminal phase (pure controller — no widgets; the
/// bank fires synchronously on the terminal apply).
void playOut(GameController c) {
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(
    {'run_won', 'run_lost'}.contains(c.phase),
    isTrue,
    reason: 'bot must reach a terminal phase (guard=$guard)',
  );
}

Map<String, Object?> fullerRecord({
  String result = 'lost',
  String character = 'gambler',
  int floor = 8,
  int seed = 999999999,
  String? killedBy = 'ashglass_sentinel',
  int fights = 99,
  String trace = 'chchchchh',
  String epithet = 'the_well_oiled',
}) => {
  'date': '2026-08-25',
  'character': character,
  'difficulty': 'hard',
  'ascension': 20,
  'result': result,
  'floor': floor,
  'floors': 9,
  'seed': seed,
  'embers': 9999,
  if (killedBy != null) 'killed_by': killedBy,
  'fights': fights,
  'trace': trace,
  'epithet': epithet,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compact codec roundtrips and drops what it cannot read', () {
    final t = RunTrace.fromJson({
      'marks': [markClean, markHurt, markClean],
    });
    expect(t.toCompact(), 'chc');
    final back = RunTrace.fromCompact('chc', outcome: 'lost');
    expect(back.marks, [markClean, markHurt, markClean]);
    expect(back.outcome, 'lost');
    // The rebuilt trace paints its terminal cell from the record's result.
    expect(traceGrid(back), '🟩🟨🟥');
    expect(traceGrid(RunTrace.fromCompact('chc', outcome: 'won')), '🟩🟨🔥');
    // Unknown characters and outcomes are dropped, never guessed.
    final junk = RunTrace.fromCompact('cxh!', outcome: 'abandoned');
    expect(junk.marks, [markClean, markHurt]);
    expect(junk.outcome, isNull);
    expect(RunTrace.fromCompact('').marks, isEmpty);
  });

  test('a won run banks fights, trace, and the worn epithet', () {
    final c = GameController();
    c.meta.selectedEpithet = 'the_delver';
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    final r = c.meta.runHistory.first;
    expect(r['result'], 'won');
    expect(r['fights'], c.sim!.run!['fights_won']);
    expect((r['fights'] as int) > 0, isTrue);
    expect(r['trace'], c.runTrace.toCompact());
    expect((r['trace'] as String).length, c.runTrace.marks.length);
    expect(r['epithet'], 'the_delver');
  });

  test('a lost run banks the same facts; no epithet key when none worn', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    final r = c.meta.runHistory.first;
    expect(r['result'], 'lost');
    expect(r['fights'], c.sim!.run!['fights_won']);
    expect(r['trace'], c.runTrace.toCompact());
    expect(r.containsKey('epithet'), isFalse);
    // The remembered grid ends on the fallen floor, same as the live one.
    final f = DelverCardFacts.fromRecord(r);
    expect(f.traceGridText, traceGrid(c.runTrace));
    expect(f.traceGridText, endsWith('🟥'));
  });

  test('fromRecord restores fights, grid, and the worn title everywhere', () {
    final f = DelverCardFacts.fromRecord(fullerRecord());
    expect(f.fightsKnown, isTrue);
    expect(f.fightsWon, 99);
    expect(f.traceGridText, '🟩🟨🟩🟨🟩\n🟨🟩🟨🟥');
    expect(f.epithetTitle, 'the Well-Oiled');
    expect(f.nameLine, 'The Gambler, the Well-Oiled');
    // Worn-at-the-time is a banked fact now — the epitaph states it too.
    expect(
      f.epitaph,
      'The delve took The Gambler, the Well-Oiled — '
      'Ashglass Sentinel ended the run on floor 8.',
    );
  });

  test('absent fuller keys keep the v0.56.0 omissions exactly', () {
    final r = fullerRecord()
      ..remove('fights')
      ..remove('trace')
      ..remove('epithet');
    final f = DelverCardFacts.fromRecord(r);
    expect(f.fightsKnown, isFalse);
    expect(f.traceGridText, isEmpty);
    expect(f.epithetTitle, isEmpty);
    expect(f.epitaph, isNot(contains('Well-Oiled')));
  });

  testWidgets('the fuller worst case never overflows the fixed canvas', (
    tester,
  ) async {
    // Longest shipped name+epithet form, 2-row trace, big fights and ember
    // figures, two-clause loss epitaph with the worn title inside it.
    final f = DelverCardFacts.fromRecord(fullerRecord());
    expect(f.epitaph, contains('Ashglass Sentinel ended the run on floor 8.'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Center(child: DelverCard(f)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('9999 embers banked · 99 fights won'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-epitaph')), findsOneWidget);
  });
}
