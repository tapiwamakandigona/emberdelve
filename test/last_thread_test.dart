// test/last_thread_test.dart — v0.86.0 The Foe's Last Thread.
//
// The loss-side mirror of the Narrow Climb: a lost summary names how close
// the killer stood to falling, gated by the SAME 30% rule. Wins and losses
// to a healthy foe say nothing; an unknown killer id is never named.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
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
  test('a loss to a foe inside the rule gets the line, named honestly', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    final e = c.sim!.enemy!;
    final name = e['id'];
    e['max_hp'] = 30;
    e['hp'] = 9; // exactly 30% — the rule is <=
    final line = lastThreadLine(c);
    expect(line, isNotNull);
    expect(line, contains('hung by a thread — 9 HP standing.'));
    expect(name, isNotNull); // the killer the obituary also names
  });

  test('a loss to a healthy foe says nothing', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    c.sim!.enemy!['max_hp'] = 30;
    c.sim!.enemy!['hp'] = 10; // one past the boundary
    expect(lastThreadLine(c), isNull);
  });

  test('a win says nothing', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    expect(lastThreadLine(c), isNull);
  });

  test('an unknown killer id is never named', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    c.sim!.enemy!['id'] = 'retired_ghost';
    c.sim!.enemy!['max_hp'] = 30;
    c.sim!.enemy!['hp'] = 1;
    expect(lastThreadLine(c), isNull);
  });
}
