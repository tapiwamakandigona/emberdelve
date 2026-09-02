// test/runemark_test.dart — v0.134.0 The Runemark.
//
// The tenth vista: the Six Marks summit (every rune worked once). The gate
// is FROZEN at six — a gate tracking the live rune set would re-lock an
// earned vista if the anvil grows (the v0.100 hearthgold lesson) — while
// the six_marks BADGE keeps promise wording and moves with the set.
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runemark stands tenth, with a real grade', () {
    // v0.152.0: tenthfire appended after it — the order pin moves to the
    // INDEX (append-only contract), the 'last' claim retires.
    expect(vistasOrder.indexOf('runemark'), 9);
    expect(vistasOrder.length, 13);
    final def = vistas['runemark']!;
    expect(def.unlockLine, 'Temper every rune the anvil offers.');
    expect(
      def.hueDeg != 0 || def.satMul != 1 || def.valMul != 1,
      isTrue,
      reason: 'a vista must actually change the light',
    );
  });

  test('the resolver flips exactly at six distinct runes', () {
    bool at(int marked) => vistaUnlockedFor(
      'runemark',
      delversCleared: 0,
      runsWon: 0,
      distinctFelled: 0,
      hardWins: 0,
      provingsCleared: 0,
      bestFloor: 0,
      talesHeard: 0,
      doubledWins: 0,
      tempersSet: 0,
      charsUnlocked: 0,
      runesMarked: marked,
    );
    expect(at(5), isFalse);
    expect(at(6), isTrue);
    expect(at(999), isTrue);
  });

  test('the controller gate reads the junk-proofed live counter', () {
    final c = GameController();
    c.meta.runesTempered.addAll({'blade', 'aegis', 'surge', 'echo', 'mend'});
    c.meta.runesTempered.add('ghost_rune'); // junk never counts
    expect(c.vistaUnlocked('runemark'), isFalse);
    c.meta.runesTempered.add('gilt');
    expect(c.vistaUnlocked('runemark'), isTrue);
    expect(c.meta.runesTempered.where(faceRunes.contains).length, 6);
  });
}
