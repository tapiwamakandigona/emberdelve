// test/pictured_card_test.dart — v0.70.0 "The Pictured Card": the delver
// stands on their own Delver's Card (key 'card-delver'), in their worn dye.
// The card stays a pure function of DelverCardFacts. Design doc:
// docs/improvements/v0.70.0-lead-scout.md.
//
// Pins:
//   1. fromController banks charId and the delver's worn dye (dyeFor —
//      per-delver map, not the legacy global field).
//   2. fromRecord resolves the CURRENT coat when given meta (portraiture),
//      and stays undyed without it.
//   3. Widget: the card shows the sprite; the old trophy/flame icon is gone.
//
// Seeds: 1 wins on easy (kindler, boons — pinned table).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromController banks the run delver and their worn dye', () {
    final c = GameController();
    c.meta.ownedDyes.add('emberwash');
    c.meta.charDye['kindler'] = 'emberwash';
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    final facts = DelverCardFacts.fromController(c);
    expect(facts.charId, 'kindler');
    expect(facts.dyeId, 'emberwash');
  });

  test('fromRecord paints the current coat with meta, undyed without', () {
    final m = MetaState();
    m.charDye['kindler'] = 'emberwash';
    final r = <String, Object?>{
      'result': 'won',
      'character': 'kindler',
      'difficulty': 'easy',
      'seed': 1,
      'embers': 10,
      'floor': 9,
    };
    expect(DelverCardFacts.fromRecord(r, meta: m).dyeId, 'emberwash');
    expect(DelverCardFacts.fromRecord(r).dyeId, defaultDye);
    expect(DelverCardFacts.fromRecord(r, meta: m).charId, 'kindler');
  });

  testWidgets('the card shows the delver, not a trophy', (tester) async {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    final facts = DelverCardFacts.fromController(c);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Material(child: Center(child: DelverCard(facts))),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('card-delver')), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });
}
