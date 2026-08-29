// test/counted_draught_test.dart — v0.92.0 "The Counted Draught".
//
// Event option labels rewrite their 'heal N%' token to the counted heal:
// the sim's own arithmetic, overheal cap included, 'heals nothing' at full
// HP, untouched data files, and parity against the real event_choose.
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live mid-run sim via the pinned shop walk (kindler easy seed 7 =
/// hp 17/30, gold 98 — see ration_preview_test.dart).
GameController liveSim() {
  final c = GameController();
  c.startRun(character: 'kindler', seed: 7, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'shop' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'shop', reason: 'seed 7 must reach a shop');
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the heal token is counted, capped, and honest at full HP', () {
    final c = liveSim(); // 17/30
    const bathe = OptionDef('Bathe (heal 40%)', {'heal_pct': 40});
    expect(countedOptionLabel(c, bathe), 'Bathe (heal 12 HP)');
    c.sim!.player['hp'] = 28;
    expect(
      countedOptionLabel(c, bathe),
      'Bathe (heal 2 HP)',
      reason: '28/30 caps 12 to 2',
    );
    c.sim!.player['hp'] = 30;
    expect(countedOptionLabel(c, bathe), 'Bathe (heals nothing)');
  });

  test('combined labels rewrite only the heal token', () {
    final c = liveSim(); // 17/30
    const flask = OptionDef('Buy the flask (-12 gold, heal 30%)', {
      'gold': -12,
      'heal_pct': 30,
    });
    expect(countedOptionLabel(c, flask), 'Buy the flask (-12 gold, heal 9 HP)');
    const walk = OptionDef('Move on', {});
    expect(
      countedOptionLabel(c, walk),
      'Move on',
      reason: 'no token, no rewrite',
    );
  });

  test('the promise equals the heal event_choose then performs', () {
    final c = liveSim(); // 17/30
    c.sim!.phase = 'event';
    c.sim!.event = 'ember_shrine'; // option 2 = 'Pray quietly (heal 25%)'
    final def = eventDef('ember_shrine');
    final label = countedOptionLabel(c, def.options[1]);
    expect(label, 'Pray quietly (heal 7 HP)', reason: '25% of 30 = 7');
    final before = c.sim!.player['hp'] as int;
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.player['hp'], before + 7);
  });

  testWidgets('the event screen prints the counted label', (tester) async {
    final c = liveSim();
    c.sim!.phase = 'event';
    c.sim!.event = 'ember_shrine';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Pray quietly (heal 7 HP)'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
