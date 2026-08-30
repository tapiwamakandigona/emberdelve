// test/mend_rune_test.dart — v0.124.0 The Mender's Mark.
//
// The fifth temper rune: on the tempered die's NATURAL face, assigning it
// mends 1 HP — capped at max hp (counted-heal honesty: a full delver banks
// nothing and no phantom event fires). Echo precedent: the payoff happens
// after the assignment resolves, outside the value math, for either verb.
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

Sim _inCombat({int face = 3}) {
  final sim = Sim(123)..apply({'type': 'start_run'});
  sim.run!['custom_dice'] = {
    'custom_1': {'base': 'd6', 'face': face, 'rune': 'mend'},
  };
  sim.player['dice'] = <String>['custom_1'];
  combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
  return sim;
}

/// Pin the roll to the tempered face so the trigger is deterministic.
void _pinRoll(Sim sim, int face) {
  sim.player['rolled'] = <int>[face];
  sim.player['rolled_face'] = <int>[face];
  sim.player['rolled_max'] = <bool>[false];
  sim.player['combo_bonus'] = <int>[0];
  sim.player['assigned'] = <String, String>{};
}

void main() {
  test('mend is legal vocabulary with honest copy', () {
    expect(faceRunes.contains('mend'), isTrue);
    expect(runeName('mend'), 'Mend');
    expect(runeBlurb('mend'), contains('mend 1 HP'));
  });

  test('the natural face mends 1 on assignment, either verb', () {
    for (final verb in ['attack', 'block']) {
      final sim = _inCombat();
      sim.player['hp'] = 10;
      _pinRoll(sim, 3);
      final events = sim.apply({'type': 'assign', 'die': 1, 'action': verb});
      expect(sim.player['hp'], 11, reason: 'mend heals 1 on $verb');
      expect(
        events.any(
          (e) => e['type'] == 'player_healed' && e['source'] == 'mend_rune',
        ),
        isTrue,
      );
      expect(
        events.any((e) => e['type'] == 'rune_triggered'),
        isTrue,
        reason: 'the trigger is announced like every rune',
      );
    }
  });

  test('a full delver mends nothing — no phantom event', () {
    final sim = _inCombat();
    sim.player['hp'] = sim.player['max_hp'];
    _pinRoll(sim, 3);
    final events = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    expect(sim.player['hp'], sim.player['max_hp']);
    expect(
      events.where((e) => e['type'] == 'player_healed'),
      isEmpty,
      reason: 'counted-heal honesty: no gain, no event',
    );
  });

  test('a non-matching face pays nothing', () {
    final sim = _inCombat(face: 5);
    sim.player['hp'] = 10;
    _pinRoll(sim, 3); // rolled 3, tempered face is 5
    sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    expect(sim.player['hp'], 10);
  });

  test('the temper command accepts mend end-to-end', () {
    final sim = Sim(9)..apply({'type': 'start_run'});
    // Reach a rest the honest way is covered elsewhere; the command layer
    // validates rune vocabulary regardless of phase gates, so drive the
    // ledger directly (face_forge idiom).
    sim.run!['custom_dice'] = {};
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 2,
      'rune': 'mend',
    });
    expect(
      events.any(
        (e) => e['type'] == 'invalid' && e['reason'] == 'unknown_rune',
      ),
      isFalse,
      reason: 'mend must not be rejected as unknown',
    );
  });

  test('mend copy is honest (no pressure language)', () {
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
    final t = '${runeName('mend')} ${runeBlurb('mend')}'.toLowerCase();
    for (final b in banned) {
      expect(t.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
