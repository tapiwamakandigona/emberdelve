// test/run_history_test.dart — v0.3.4 run history (review note #4):
//   1. Every ended run (won/lost/abandoned) prepends one record; capped.
//   2. Records carry date/character/difficulty/result/floor/seed/embers,
//      and the daily flag for dailies.
//   3. runHistory round-trips through meta JSON.
//   4. The Ledger renders a RECENT DELVES section from real records.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

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
        c.apply(
            {'type': 'choose_node', 'node': (e['$p'] as List).cast<int>().first});
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
  test('ended runs record history newest-first with full fields', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 11);
    driveToTerminal(c);
    expect(c.meta.runHistory, hasLength(1));

    c.startRun(character: 'kindler', seed: 12);
    c.abandonRun();
    expect(c.meta.runHistory, hasLength(2));

    final newest = c.meta.runHistory.first; // the abandoned one
    expect(newest['result'], 'abandoned');
    expect(newest['seed'], 12);
    expect(newest['embers'], 0, reason: 'walking away banks nothing');

    final finished = c.meta.runHistory[1];
    expect(finished['seed'], 11);
    expect(finished['character'], 'kindler');
    expect(finished['difficulty'], isNotNull);
    expect({'won', 'lost'}.contains(finished['result']), isTrue);
    expect(finished['floor'], greaterThan(0));
    expect(finished['daily'], isNull, reason: 'normal run: no daily flag');
  });

  test('daily runs are flagged and history is capped', () {
    final c = GameController();
    c.startDailyRun(character: 'kindler');
    driveToTerminal(c);
    expect(c.meta.runHistory.first['daily'], isTrue);

    final m = MetaState();
    for (var i = 0; i < MetaState.runHistoryCap + 10; i++) {
      m.addRunRecord({'seed': i});
    }
    expect(m.runHistory, hasLength(MetaState.runHistoryCap));
    expect(m.runHistory.first['seed'], MetaState.runHistoryCap + 9,
        reason: 'newest kept, oldest trimmed');
  });

  test('runHistory round-trips through meta JSON', () {
    final m = MetaState();
    m.addRunRecord({
      'date': '2026-07-24',
      'character': 'kindler',
      'difficulty': 'hard',
      'ascension': 1,
      'result': 'lost',
      'floor': 5,
      'floors': 9,
      'seed': 777,
      'embers': 12,
      'daily': true,
    });
    final back = MetaState.fromJson(
        Map<String, dynamic>.from(m.toJson().map((k, v) => MapEntry(k, v))));
    expect(back.runHistory, hasLength(1));
    expect(back.runHistory.first['seed'], 777);
    expect(back.runHistory.first['result'], 'lost');
    expect(back.runHistory.first['daily'], isTrue);
  });

  testWidgets('ledger renders RECENT DELVES from records', (tester) async {
    final c = GameController();
    c.meta.addRunRecord({
      'date': '2026-07-24',
      'character': 'kindler',
      'difficulty': 'normal',
      'ascension': 0,
      'result': 'lost',
      'floor': 5,
      'floors': 9,
      'seed': 777,
      'embers': 12,
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: LedgerScreen(c),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    // The ledger ListView builds lazily; scroll the section into view.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recent-delves')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('recent-delves')), findsOneWidget);
    expect(find.textContaining('fell on floor 5 of 9'), findsOneWidget);

    // Empty history: the section stays hidden entirely.
    final c2 = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: LedgerScreen(c2),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('recent-delves')), findsNothing);
  });
}
