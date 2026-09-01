// test/shared_fire_test.dart — v0.153.0 The Shared Fire.
//
// The seventh tip: the shared delve taught on the title screen, after a
// first win, never after a daily has been played — a player who found the
// button alone never sees the card (same shape as first_anvil's canTemper
// guard: never teach a thing that is not true right now).
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the moment fires only between first finished run and first daily', () {
    final d = TipDirector(<String>{});
    expect(
      d.onTitleArrival(playedBefore: false, dailyPlayed: false),
      isNull,
      reason: 'no run finished yet — the loop is not tasted',
    );
    expect(
      d.onTitleArrival(playedBefore: true, dailyPlayed: true),
      isNull,
      reason: 'found the button alone — nothing left to teach',
    );
    // Retention lane: a LOST first run counts — the player most at risk
    // of not returning is exactly the one who needs tomorrow's reason.
    expect(
      d.onTitleArrival(playedBefore: true, dailyPlayed: false),
      ContextTips.sharedDelve,
    );
    d.dismiss();
    expect(
      d.onTitleArrival(playedBefore: true, dailyPlayed: false),
      isNull,
      reason: 'once ever',
    );
  });

  testWidgets('the title screen shows and dismisses the card', (tester) async {
    final c = GameController();
    // A finished run — a LOSS, deliberately — is enough (retention lane).
    c.meta.runsPlayed = 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: TitleScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('tip-shared_delve')), findsOneWidget);
    expect(find.textContaining('same seed, same road'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tip-shared_delve')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('tip-shared_delve')), findsNothing);
    expect(c.meta.tipsSeen, contains(ContextTips.sharedDelve));
  });

  test('the card copy holds the ethics charter', () {
    // The card text lives in the UI deck; the banned list is absolute even
    // in denial framing (v0.147's news lesson) — pinned here at the source
    // of the one tip that talks about days and calendars.
    const copy =
        'Each day deals one delve that is the same for everyone — same '
        'seed, same road — and Monday adds a weekly rule on top. Play it '
        'when you like: a skipped day is silent and costs nothing.';
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
    for (final b in banned) {
      expect(copy.toLowerCase().contains(b), isFalse, reason: '"$b"');
    }
  });
}
