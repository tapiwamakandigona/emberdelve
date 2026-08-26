// test/narrow_climb_test.dart — v0.85.0 The Narrow Climb.
//
// A won summary states how close it ran, gated by the SAME low-HP danger
// rule that darkens the combat music (HP*10 <= max*3): the line and the
// danger bed can never disagree about what "close" means. Losses and
// comfortable wins say nothing.
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
  test('a win inside the danger rule gets the line, boundary inclusive', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    c.sim!.player['max_hp'] = 30;
    c.sim!.player['hp'] = 9; // exactly 30% — the rule is <=
    expect(narrowClimbLine(c), 'A narrow climb home — 9 HP standing.');
    c.sim!.player['hp'] = 1;
    expect(narrowClimbLine(c), 'A narrow climb home — 1 HP standing.');
  });

  test('a comfortable win says nothing', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_won');
    c.sim!.player['max_hp'] = 30;
    c.sim!.player['hp'] = 10; // one past the boundary
    expect(narrowClimbLine(c), isNull);
  });

  test('a loss says nothing, even at low HP', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, difficulty: 'easy');
    playOut(c);
    expect(c.phase, 'run_lost');
    expect(narrowClimbLine(c), isNull);
  });
}
