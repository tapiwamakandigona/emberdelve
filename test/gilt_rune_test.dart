// test/gilt_rune_test.dart — v0.130.0 The Gilded Face.
//
// The sixth temper rune: on the tempered die's NATURAL face, assigning it
// pays 2 gold, either verb — the on_max_gold exception extended (mid-
// combat gold is incidental economy). Mend precedent: the payoff resolves
// after the assignment, outside the value math.
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

Sim _inCombat({int face = 3}) {
  final sim = Sim(123)..apply({'type': 'start_run'});
  sim.run!['custom_dice'] = {
    'custom_1': {'base': 'd6', 'face': face, 'rune': 'gilt'},
  };
  sim.player['dice'] = <String>['custom_1'];
  combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
  return sim;
}

void _pinRoll(Sim sim, int face) {
  sim.player['rolled'] = <int>[face];
  sim.player['rolled_face'] = <int>[face];
  sim.player['rolled_max'] = <bool>[false];
  sim.player['combo_bonus'] = <int>[0];
  sim.player['assigned'] = <String, String>{};
}

void main() {
  test('gilt is legal vocabulary with honest copy', () {
    expect(faceRunes.contains('gilt'), isTrue);
    expect(runeName('gilt'), 'Gilt');
    expect(runeBlurb('gilt'), contains('2 gold'));
  });

  test('the natural face pays 2 gold on assignment, either verb', () {
    for (final verb in ['attack', 'block']) {
      final sim = _inCombat();
      final gold0 = sim.run!['gold'] as int;
      _pinRoll(sim, 3);
      final events = sim.apply({'type': 'assign', 'die': 1, 'action': verb});
      expect(sim.run!['gold'], gold0 + 2, reason: 'gilt pays on $verb');
      expect(
        events.any(
          (e) => e['type'] == 'gold_gained' && e['source'] == 'gilt_rune',
        ),
        isTrue,
      );
      expect(events.any((e) => e['type'] == 'rune_triggered'), isTrue);
    }
  });

  test('a non-matching face pays nothing', () {
    final sim = _inCombat(face: 5);
    final gold0 = sim.run!['gold'] as int;
    _pinRoll(sim, 3); // rolled 3, tempered face is 5
    sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    expect(sim.run!['gold'], gold0);
  });

  test('the temper command accepts gilt end-to-end', () {
    final sim = Sim(9)..apply({'type': 'start_run'});
    sim.run!['custom_dice'] = {};
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 2,
      'rune': 'gilt',
    });
    expect(
      events.any(
        (e) => e['type'] == 'invalid' && e['reason'] == 'unknown_rune',
      ),
      isFalse,
    );
  });

  test('gilt copy is honest (no pressure language)', () {
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
    final t = '${runeName('gilt')} ${runeBlurb('gilt')}'.toLowerCase();
    for (final b in banned) {
      expect(t.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
