// test/tenth_chair_test.dart — v0.152.0 The Tenth Chair.
//
// The full company's vista: Tenthfire unlocks when every delver is at the
// fire. The gate is FROZEN at ten (v0.100 lesson: a gate that tracked the
// live roster would re-lock this vista the day an eleventh delver joins).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';

bool _unlocked(int chars) => vistaUnlockedFor(
  'tenthfire',
  delversCleared: 0,
  runsWon: 0,
  distinctFelled: 0,
  hardWins: 0,
  provingsCleared: 0,
  bestFloor: 0,
  talesHeard: 0,
  doubledWins: 0,
  tempersSet: 0,
  runesMarked: 0,
  charsUnlocked: chars,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tenthfire stands last with a warm grade and a frozen gate', () {
    // v0.164.0: amethyst stands last now — the .last pin lives in
    // amethyst_test; tenthfire keeps its seat by index.
    expect(vistasOrder[10], 'tenthfire');
    expect(vistasOrder.length, 12);
    final def = vistas['tenthfire']!;
    expect(def.hueDeg, isNot(0), reason: 'a vista must actually recolor');
    expect(_unlocked(9), isFalse);
    expect(_unlocked(10), isTrue);
    // The freeze itself: today ten IS the roster, and the pin below is the
    // tripwire — when the roster grows past ten, the gate must NOT move.
    expect(
      characters.length,
      22,
      reason:
          'seventeenth delver (v0.179.0): the second circle opened past '
          'the sixteen-chair first fire and the gate did NOT move — '
          'charsUnlocked >= 10 stays frozen.',
    );
    expect(_unlocked(characters.length), isTrue);
  });

  test('the controller feeds the gate the real unlock count', () {
    final c = GameController();
    expect(c.vistaUnlocked('tenthfire'), isFalse);
    c.meta.unlockedCharacters.addAll(charactersOrder);
    expect(c.vistaUnlocked('tenthfire'), isTrue);
  });
}
