// test/amethyst_test.dart — v0.164.0 The Amethyst Vein.
//
// The won company's vista: Amethyst unlocks when every delver has carried
// a delve out of the deep. The gate is FROZEN at twelve (v0.100 lesson) and
// fed by the junk-proofed delvers_cleared count — hand-edited charWins keys
// can never open it early.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';

bool _unlocked(int cleared) => vistaUnlockedFor(
  'amethyst',
  runsWon: 0,
  distinctFelled: 0,
  hardWins: 0,
  provingsCleared: 0,
  bestFloor: 0,
  talesHeard: 0,
  doubledWins: 0,
  tempersSet: 0,
  runesMarked: 0,
  charsUnlocked: 0,
  delversCleared: cleared,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('amethyst stands last with a violet grade and a frozen gate', () {
    expect(vistasOrder.last, 'amethyst');
    expect(vistasOrder.length, 12);
    final def = vistas['amethyst']!;
    expect(def.hueDeg, isNot(0), reason: 'a vista must actually recolor');
    expect(_unlocked(11), isFalse);
    expect(_unlocked(12), isTrue);
    // The freeze itself: today twelve IS the roster, and the pin below is
    // the tripwire — when the roster grows past twelve, the gate must NOT
    // move. Update only this reason, never the gate.
    expect(
      characters.length,
      19,
      reason:
          'seventeenth delver (v0.179.0, DEMAND 2026-09-01f): the second '
          'circle opened past the sixteen-chair first fire and the gate '
          'did NOT move — delversCleared >= 12 stays frozen. Delve codes '
          'grew a v2 long form for index 16+; the first sixteen keep '
          'their codes byte-identical.',
    );
  });

  test('the controller feeds the gate the junk-proofed winners count', () {
    final c = GameController();
    expect(c.vistaUnlocked('amethyst'), isFalse);
    for (final id in charactersOrder) {
      c.meta.charWins[id] = 1;
    }
    expect(c.vistaUnlocked('amethyst'), isTrue);
  });

  test('junk charWins keys can never open the gate', () {
    final c = GameController();
    for (var i = 0; i < 20; i++) {
      c.meta.charWins['junk_$i'] = 5;
    }
    expect(c.vistaUnlocked('amethyst'), isFalse);
  });
}
