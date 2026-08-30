// test/six_marks_test.dart — v0.133.0 The Six Marks.
//
// The temper collection arc, mirroring the Weekly's (v0.127): the sim
// records which rune each temper set, the controller banks the DISTINCT
// runes at run end (win or lose, beside tempersSet), the resolver counts
// junk-proof against the live rune set, and two honors ride the stat.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sim records each tempered rune in run state', () {
    final sim = Sim(21)..apply({'type': 'start_run'});
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'mend'});
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 2, 'face': 2, 'rune': 'gilt'});
    expect(sim.run!['runes_tempered'], ['mend', 'gilt']);
  });

  test('run end banks distinct runes, win or lose, junk-proof at write', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 18, boons: false); // seed 18 loses
    c.sim!.phase = 'rest';
    c.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'blade'});
    (c.sim!.run!['runes_tempered'] as List).add('ghost_rune'); // junk
    var guard = 0;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, anyOf('run_won', 'run_lost'));
    expect(
      c.meta.runesTempered,
      {'blade'},
      reason: 'banked at the terminal; junk id refused at write',
    );
  });

  test('the resolver is junk-proof at read and the honors ride it', () {
    final m = MetaState();
    m.runesTempered.addAll({'blade', 'aegis', 'stale_rune'});
    expect(statValue(m, 'runes_tempered', null), 2);
    m.runesTempered.addAll(faceRunes);
    expect(statValue(m, 'runes_tempered', null), faceRunes.length);
    expect(
      achievements['six_marks']!.target,
      faceRunes.length,
      reason: 'promise wording tracks the live anvil',
    );
    expect(achievements['third_mark']!.target, 3);
  });

  test('runesTempered survives persistence and merges as a union', () {
    final m = MetaState()..runesTempered.addAll({'mend', 'gilt'});
    final back = MetaState.fromJson(m.toJson());
    expect(back.runesTempered, {'mend', 'gilt'});
    final other = MetaState()..runesTempered.add('surge');
    expect(mergeMetaStates(back, other).runesTempered, {
      'mend',
      'gilt',
      'surge',
    });
  });
}
