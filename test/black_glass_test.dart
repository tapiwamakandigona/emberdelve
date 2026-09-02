// test/black_glass_test.dart — v0.180.0 The Black Glass.
//
// The bestiary's vista: Obsidian unlocks when eight different bosses have
// been put down. The gate is FROZEN at eight (v0.100 lesson) and fed by a
// junk-proofed count — only ids that are real bosses in the bestiary count,
// so a hand-edited bossesBeaten set can never open it early.
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';

bool _unlocked(int felled) => vistaUnlockedFor(
  'obsidian',
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
  delversCleared: 0,
  bossesFelled: felled,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('obsidian stands last with a dark glass grade and a frozen gate', () {
    expect(vistasOrder.last, 'obsidian');
    expect(vistasOrder.length, 13);
    final def = vistas['obsidian']!;
    expect(def.satMul, lessThan(1.0), reason: 'black glass drains color');
    expect(def.hueDeg, isNot(0), reason: 'a vista must actually recolor');
    expect(def.valMul, lessThan(1.0));
    expect(def.valMul, greaterThanOrEqualTo(0.8), reason: 'still legible');
    expect(def.unlockLine, contains('eight'));
    expect(_unlocked(7), isFalse);
    expect(_unlocked(8), isTrue);
    // The freeze: today eight IS the bestiary, and this pin is the tripwire
    // — when a ninth boss joins, the gate must NOT move. Update only this
    // reason, never the gate.
    expect(enemies.values.where((e) => e.boss).length, 8);
  });

  test('the older gates do not need the new counter', () {
    expect(
      vistaUnlockedFor(
        'moonveil',
        runsWon: 1,
        distinctFelled: 0,
        hardWins: 0,
        provingsCleared: 0,
        bestFloor: 0,
        talesHeard: 0,
        doubledWins: 0,
        tempersSet: 0,
        runesMarked: 0,
        charsUnlocked: 0,
        delversCleared: 0,
      ),
      isTrue,
    );
  });

  test('the controller feeds the gate a junk-proofed boss count', () {
    final c = GameController();
    expect(c.vistaUnlocked('obsidian'), isFalse);
    // Eight junk ids and a regular enemy open nothing.
    c.meta.bossesBeaten.addAll([
      for (var i = 0; i < 8; i++) 'not_a_boss_$i',
      'cinder_wisp',
    ]);
    expect(c.vistaUnlocked('obsidian'), isFalse);
    // Seven real bosses: still shut.
    final bosses = [
      for (final e in enemies.values)
        if (e.boss) e.id,
    ];
    c.meta.bossesBeaten.addAll(bosses.take(7));
    expect(c.vistaUnlocked('obsidian'), isFalse);
    c.meta.bossesBeaten.add(bosses.last);
    expect(c.vistaUnlocked('obsidian'), isTrue);
  });
}
