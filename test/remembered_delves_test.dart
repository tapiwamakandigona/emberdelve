// test/remembered_delves_test.dart — v0.43.0 The Remembered Delves.
//
// Every remembered run in the Ledger's RECENT DELVES list is tap-to-copy:
// the row rebuilds its Delve Code from the record's seed/delver/difficulty/
// ascension and puts it on the clipboard. Records that cannot encode (a
// pre-v0.3.4 record with seed 0) stay quiet — no affordance, no lie.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('history rows copy their Delve Code; legacy rows stay quiet', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
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
    // Oldest first: addRunRecord prepends, so insert legacy, then modern.
    c.meta.addRunRecord({
      'date': '2026-08-01',
      'character': 'kindler',
      'difficulty': 'normal',
      'ascension': 0,
      'result': 'lost',
      'floor': 3,
      'floors': 8,
      'seed': 0, // pre-v0.3.4 record: no seed remembered
      'embers': 10,
    });
    c.meta.addRunRecord({
      'date': '2026-08-24',
      'character': 'gambler',
      'difficulty': 'hard',
      'ascension': 2,
      'result': 'won',
      'floor': 8,
      'floors': 8,
      'seed': 42,
      'embers': 90,
    });
    final expected = encodeDelveCode(
      seed: 42,
      character: 'gambler',
      difficulty: 'hard',
      ascension: 2,
    );
    expect(expected, isNotNull);

    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('history-code-$expected')),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await pumpFor(tester, 200);

    // Exactly one row offers a code — the legacy seed-0 record shows none.
    expect(
      find.textContaining('tap to copy its Delve Code'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('history-code-$expected')));
    await pumpFor(tester, 200);

    final copied = calls.where((m) => m.method == 'Clipboard.setData');
    expect(copied, isNotEmpty, reason: 'tap must copy to the clipboard');
    expect(
      (copied.last.arguments as Map)['text'],
      expected,
      reason: 'the copied text must be the row\'s own Delve Code',
    );
    await pumpFor(tester, 200);
  });
}
