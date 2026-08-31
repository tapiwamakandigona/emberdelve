// test/forgelight_test.dart — v0.126.0 The Forgelight.
//
// The ninth vista, fed by the lifetime temper counter (v0.125.0): unlocks
// at ten tempered faces, appended LAST, a real grade (never the identity),
// and the controller gate reads the live meta.
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgelight keeps its slot with an honest unlock line', () {
    // v0.134.0: runemark appended — index pin, not 'last' (the lesson).
    expect(vistasOrder.indexOf('forgelight'), 8);
    final def = vistas['forgelight']!;
    expect(def.unlockLine, 'Temper ten die faces.');
    expect(
      def.hueDeg != 0 || def.satMul != 1 || def.valMul != 1,
      isTrue,
      reason: 'a vista must actually change the light',
    );
  });

  test('the resolver flips exactly at ten tempers', () {
    bool at(int tempers) => vistaUnlockedFor(
      'forgelight',
      runsWon: 0,
      distinctFelled: 0,
      hardWins: 0,
      provingsCleared: 0,
      bestFloor: 0,
      talesHeard: 0,
      doubledWins: 0,
      tempersSet: tempers,
      charsUnlocked: 0,
      runesMarked: 0,
    );
    expect(at(9), isFalse);
    expect(at(10), isTrue);
    expect(at(999), isTrue);
  });

  test('the controller gate reads the live counter', () {
    final c = GameController();
    expect(c.vistaUnlocked('forgelight'), isFalse);
    c.meta.tempersSet = 10;
    expect(c.vistaUnlocked('forgelight'), isTrue);
    // Derived at read time: nothing persisted, nothing to re-lock.
    c.meta.tempersSet = 10; // monotonic in real play; stays unlocked
    expect(c.vistaUnlocked('forgelight'), isTrue);
  });

  test('forgelight copy is honest (no pressure language)', () {
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
    final def = vistas['forgelight']!;
    final t = '${def.name} ${def.text} ${def.unlockLine}'.toLowerCase();
    for (final b in banned) {
      expect(t.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
