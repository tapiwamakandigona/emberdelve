// test/colored_card_test.dart — v0.99.0 The Colored Card.
//
// The Delver's Card keeps the delve's light: the player's selected vista
// paints the card background with the same translucent wash the delve
// wears (Art.backgroundWash at depth 0). Portraiture, not history — like
// the dye, vistas were never banked per run. Emberlight (identity, alpha
// 0) leaves the card byte-identical to v0.98.0 and earlier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

const DelverCardFacts baseFacts = DelverCardFacts(
  won: true,
  delverName: 'Kindler',
  difficulty: 'easy',
  ascension: 0,
  traceGridText: '',
  embers: 12,
  fightsWon: 3,
  seed: 7,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('facts default to the Emberlight identity', () {
    expect(baseFacts.vistaId, defaultVista);
    // Identity wash is fully transparent: the card cannot change for a
    // player who never chose a vista.
    expect(Art.backgroundWash(0, defaultVista).a, 0);
  });

  test('controller facts carry the selected vista', () {
    final c = GameController();
    c.meta.selectedVista = 'moonveil';
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(DelverCardFacts.fromController(c).vistaId, 'moonveil');
  });

  test('record facts wear the CURRENT vista, like the dye', () {
    final r = <String, Object?>{
      'result': 'won',
      'character': 'kindler',
      'difficulty': 'easy',
      'seed': 3,
      'embers': 10,
    };
    expect(DelverCardFacts.fromRecord(r).vistaId, defaultVista);
    final meta = MetaState()..selectedVista = 'deepshale';
    expect(DelverCardFacts.fromRecord(r, meta: meta).vistaId, 'deepshale');
  });

  testWidgets('the card paints the vista wash the delve wears', (tester) async {
    const facts = DelverCardFacts(
      won: true,
      delverName: 'Kindler',
      difficulty: 'easy',
      ascension: 0,
      traceGridText: '',
      embers: 12,
      fightsWon: 3,
      seed: 7,
      vistaId: 'moonveil',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Material(child: Center(child: DelverCard(facts))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final wash = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('card-vista-wash')),
    );
    expect(wash.color, Art.backgroundWash(0, 'moonveil'));
    expect(wash.color.a, greaterThan(0));
  });

  testWidgets('Emberlight leaves the wash layer invisible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: const Material(child: Center(child: DelverCard(baseFacts))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final wash = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('card-vista-wash')),
    );
    expect(wash.color.a, 0);
  });
}
