// test/painted_trace_test.dart — v0.102.0 The Painted Trace.
//
// The Delver's Card is the one artifact built to leave the game, and its
// floor grid was emoji text — rendered with whatever emoji font the
// device vendor ships. The card now paints its own grid (deterministic on
// every platform); the share TEXT keeps the emoji grid, because text has
// no painter. Records bank the emoji string (v0.57.0), so the widget
// parses it back — unknown runes dropped, never guessed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

DelverCardFacts facts(String grid, {bool won = true}) => DelverCardFacts(
  won: won,
  delverName: 'The Kindler',
  charId: defaultCharacter,
  dyeId: '',
  difficulty: 'normal',
  ascension: 0,
  traceGridText: grid,
  embers: 40,
  fightsWon: 6,
  fightsKnown: true,
  seed: 7,
  epitaph: 'The Kindler walked out with the Ember.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the emoji grid parses back to cells, rows kept', () {
    expect(traceCells('🟩🟨🟩🟩🟨\n🟩🔥'), [
      ['c', 'h', 'c', 'c', 'h'],
      ['c', 'w'],
    ]);
    expect(traceCells('🟩🟥'), [
      ['c', 'f'],
    ]);
    expect(traceCells(''), isEmpty);
  });

  test('unknown runes are dropped, never guessed', () {
    expect(traceCells('🟩🕯️🟨'), [
      ['c', 'h'],
    ]);
  });

  testWidgets('the card paints the grid and drops the emoji text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final f = facts('🟩🟨🟩🟩🟨\n🟩🔥');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Material(child: Center(child: DelverCard(f))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('card-trace-grid')), findsOneWidget);
    expect(find.text(f.traceGridText), findsNothing);
    // The label states floors and outcome — TalkBack never reads squares
    // one by one (traceSemanticLabel precedent). Per-floor counts are NOT
    // stated: the outcome cell replaced its floor's mark, so any count
    // would be a guess.
    expect(
      find.bySemanticsLabel('Floor trace: 7 floors, the Ember claimed.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an empty trace paints nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Material(child: Center(child: DelverCard(facts('')))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('card-trace-grid')), findsNothing);
  });

  testWidgets('the claimed Ember cell wears the gold ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Material(child: Center(child: PaintedTrace('🟩🔥'))),
      ),
    );
    final ringed = tester.widgetList<Container>(find.byType(Container)).where((
      w,
    ) {
      final d = w.decoration;
      return d is BoxDecoration && d.border != null;
    });
    expect(ringed.length, 1);
  });
}
