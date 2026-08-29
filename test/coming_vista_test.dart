// test/coming_vista_test.dart — v0.88.0 The Coming Vista.
//
// The summary names the nearest still-locked progressive vista ONLY when
// this run moved its counter, with real numbers. No movement = no line;
// unlocked = no line. Movement reads existing transients, so the rules
// here pin those semantics too (first-ever run has no deepest-mark
// transient by v0.61.0 design).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/ui/screens.dart';

void playOut(GameController c) {
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

void main() {
  test('a first win names the Verdigris count with real numbers', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    // First-ever run: no deepest-mark transient (v0.61.0 first-run guard),
    // and a floor-9 win unlocks Deepshale anyway; felled foes are the mover.
    expect(c.runFirstFelled, isNotEmpty);
    final n = c.meta.enemyFelled.length;
    expect(n, lessThan(15));
    expect(
      comingVistaLine(c),
      'The Verdigris vista waits — $n of 15 different foes felled.',
    );
  });

  test('nearest wins: the higher fraction speaks when both moved', () {
    final c = GameController();
    c.meta.bestFloor = 1; // a prior record exists, so a raise announces
    // Seed 22 kindler easy: loss with 2 distinct felled (2/15) and a new
    // deepest floor 7 (7/9) — the depth fraction is the nearest by far.
    c.startRun(character: 'kindler', seed: 22, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    expect(c.runFirstFelled, isNotEmpty);
    expect(c.pendingDeepestFloor, isNotNull);
    expect(c.meta.enemyFelled.length, 2);
    expect(c.meta.bestFloor, 7);
    expect(
      comingVistaLine(c),
      'The Deepshale vista waits — deepest floor\u00A07\u00A0of\u00A09.',
    );
  });

  test('tales heard this run name the Hearthgold with real numbers', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    // Silence the competing movers: verdigris unlocked drops its line.
    for (var i = 0; i < 15; i++) {
      c.meta.enemyFelled['foe_$i'] = 1;
    }
    expect(c.pendingDeepestFloor, isNull); // v0.61.0 first-run guard
    c.runTalesHeard = 2;
    c.meta.hearthTalesHeard = 2;
    expect(
      comingVistaLine(c),
      'The Hearthgold vista waits — '
      '2\u00A0of\u00A0${hearthTales.length} tales heard.',
    );
    // Unlocked = no line: the full cycle heard leaves nothing to tease.
    c.meta.hearthTalesHeard = hearthTales.length;
    expect(comingVistaLine(c), isNull);
  });

  test('a run that moved nothing says nothing', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    final c2 = GameController()..meta.enemyFelled.addAll(c.meta.enemyFelled);
    c2.meta.bestFloor = c.meta.bestFloor;
    c2.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c2);
    expect(c2.phase, 'run_lost');
    expect(c2.runFirstFelled, isEmpty); // same foes, no new firsts
    expect(c2.pendingDeepestFloor, isNull); // same floor, no new record
    expect(comingVistaLine(c2), isNull);
  });

  test('unlocked vistas are never pitched', () {
    final c = GameController();
    // 15 distinct already banked: Verdigris stands unlocked before the run.
    c.meta.enemyFelled.addAll({for (var i = 0; i < 15; i++) 'ghost_$i': 1});
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    // Win reaches floor 9: Deepshale unlocks too. Nothing left to name.
    expect(c.vistaUnlocked('verdigris'), isTrue);
    expect(c.vistaUnlocked('deepshale'), isTrue);
    expect(comingVistaLine(c), isNull);
  });

  test('mid-run says nothing', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    expect(comingVistaLine(c), isNull);
  });
}
