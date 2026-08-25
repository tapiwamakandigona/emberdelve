// test/answered_blow_test.dart — v0.47.0 "The Answered Blow" response
// puzzles: the `charge` and `counter` intent kinds and their contracts.
//
// Charge contract (docs/improvements/v0.47.0-answered-blow-design.md):
//   * intent_shown carries the raw break `threshold`;
//   * HP damage from dice this turn accumulates in enemy['charge_taken'];
//   * reaching the threshold flips the intent to a no-op `stagger` LIVE
//     (charge_broken event, then a fresh intent_shown);
//   * an unbroken charge resolves at end_turn exactly like an attack of its
//     shown amount; a broken one resolves as enemy_staggered / no damage;
//   * the meter resets when the next telegraph is shown.
// Counter contract:
//   * every non-killing attack die costs the player the shown amount, block
//     absorbing first (counter_struck event, honest blocked/damage split);
//   * a killing blow resolves the win BEFORE the counter can answer;
//   * at end_turn the stance passes — the enemy does not attack.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/combos.dart';
import 'package:emberdelve/data/enemies.dart';

/// Start a normal run and drop straight into combat vs [enemyId] at [layer]
/// (bypasses the map so the tested pattern is exactly the authored one).
Sim _combatVs(String enemyId, {int layer = 5, bool elite = false}) {
  final sim = Sim(1);
  sim.apply({'type': 'start_run'});
  final events = <Map<String, Object?>>[];
  combatBegin(sim, enemyId, elite, events, layer: layer);
  return sim;
}

/// Force a known rolled pool (keeps combo_bonus consistent with the pool so
/// attack values are exactly what the test says they are).
void _forcePool(Sim sim, List<int> values) {
  sim.apply({'type': 'roll'});
  sim.player['rolled'] = List<int>.from(values);
  sim.player['rolled_max'] = List<bool>.filled(values.length, false);
  sim.player['combo_bonus'] = detectCombos(values).bonus;
}

void main() {
  group('charge — the burst check', () {
    test('intent_shown carries the raw threshold; pattern amount adjusts', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      final events = <Map<String, Object?>>[];
      combatBegin(sim, 'vent_ram', false, events, layer: 5);
      final shown = events.lastWhere((e) => e['type'] == 'intent_shown');
      expect(shown['kind'], equals('charge'));
      expect(shown['amount'], equals(enemies['vent_ram']!.pattern[0].amount));
      expect(
        shown['threshold'],
        equals(enemies['vent_ram']!.pattern[0].block),
        reason: 'break threshold is a puzzle knob — never difficulty-scaled',
      );
    });

    test('reaching the threshold breaks the charge live', () {
      final sim = _combatVs('vent_ram');
      _forcePool(sim, [6, 5, 3]); // no pair/straight: values are exact
      final ev1 = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(ev1.any((e) => e['type'] == 'charge_broken'), isFalse);
      expect(sim.enemy!['charge_taken'], equals(6));
      expect((sim.enemy!['intent'] as Map)['kind'], equals('charge'));
      final ev2 = sim.apply({'type': 'assign', 'die': 2, 'action': 'attack'});
      final broken = ev2.firstWhere((e) => e['type'] == 'charge_broken');
      expect(broken['taken'], equals(11)); // 6 + 5 >= threshold 9
      expect((sim.enemy!['intent'] as Map)['kind'], equals('stagger'));
      expect(
        ev2.any((e) => e['type'] == 'intent_shown' && e['kind'] == 'stagger'),
        isTrue,
        reason: 'the flipped intent is re-announced so the badge updates',
      );
      final hpBefore = sim.player['hp'] as int;
      final end = sim.apply({'type': 'end_turn'});
      expect(end.any((e) => e['type'] == 'enemy_staggered'), isTrue);
      expect(end.any((e) => e['type'] == 'enemy_attacked'), isFalse);
      expect(sim.player['hp'], equals(hpBefore), reason: 'stagger = no hit');
    });

    test('an unbroken charge lands as a normal blockable attack', () {
      final sim = _combatVs('vent_ram');
      _forcePool(sim, [6, 5, 3]);
      // Turtle instead: all block, zero damage dealt.
      sim.apply({'type': 'assign', 'die': 1, 'action': 'block'});
      sim.apply({'type': 'assign', 'die': 2, 'action': 'block'});
      sim.apply({'type': 'assign', 'die': 3, 'action': 'block'});
      final block = sim.player['block'] as int;
      final hpBefore = sim.player['hp'] as int;
      final amount = (sim.enemy!['intent'] as Map)['amount'] as int;
      final end = sim.apply({'type': 'end_turn'});
      final atk = end.firstWhere((e) => e['type'] == 'enemy_attacked');
      expect(atk['amount'], equals(amount));
      expect(atk['charged'], isTrue);
      final expectedDmg = amount - block < 0 ? 0 : amount - block;
      expect(sim.player['hp'], equals(hpBefore - expectedDmg));
    });

    test('the break meter resets with the next telegraph', () {
      final sim = _combatVs('vent_ram');
      // Survive the unbroken 34-point hit so the turn actually advances.
      sim.player['max_hp'] = 99;
      sim.player['hp'] = 99;
      _forcePool(sim, [6, 5, 3]);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'}); // 6 < 9
      sim.apply({'type': 'end_turn'});
      expect(sim.enemy!['charge_taken'], equals(0));
    });

    test('block-absorbed damage does not count toward the break', () {
      final sim = _combatVs('vent_ram');
      sim.enemy!['block'] = 4; // hand the ram a shield for the probe
      _forcePool(sim, [6, 5, 3]);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(
        sim.enemy!['charge_taken'],
        equals(2), // 6 - 4 absorbed
        reason: 'only HP damage breaks the wind-up',
      );
    });
  });

  group('counter — the riposte stance', () {
    test('each non-killing strike costs the shown amount, block first', () {
      final sim = _combatVs('cinder_urchin');
      _forcePool(sim, [5, 4, 2]);
      final per = (sim.enemy!['intent'] as Map)['amount'] as int;
      final hp0 = sim.player['hp'] as int;
      final ev1 = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      final c1 = ev1.firstWhere((e) => e['type'] == 'counter_struck');
      expect(c1['amount'], equals(per));
      expect(c1['damage'], equals(per));
      expect(sim.player['hp'], equals(hp0 - per));
      // Guard up, then strike again: the riposte breaks on the shield.
      sim.apply({'type': 'assign', 'die': 2, 'action': 'block'});
      final ev3 = sim.apply({'type': 'assign', 'die': 3, 'action': 'attack'});
      final c3 = ev3.firstWhere((e) => e['type'] == 'counter_struck');
      expect(c3['blocked'], equals(per > 4 ? 4 : per));
      expect(c3['damage'], equals(per > 4 ? per - 4 : 0));
      expect(sim.player['hp'], equals(hp0 - per), reason: 'second riposte fully blocked');
    });

    test('a killing blow resolves before the counter answers', () {
      final sim = _combatVs('cinder_urchin');
      _forcePool(sim, [5, 4, 2]);
      sim.enemy!['hp'] = 5;
      final hp0 = sim.player['hp'] as int;
      final ev = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(ev.any((e) => e['type'] == 'encounter_won'), isTrue);
      expect(ev.any((e) => e['type'] == 'counter_struck'), isFalse);
      expect(sim.player['hp'], equals(hp0));
    });

    test('at end of turn the stance passes without an attack', () {
      final sim = _combatVs('cinder_urchin');
      _forcePool(sim, [5, 4, 2]);
      final hp0 = sim.player['hp'] as int;
      final end = sim.apply({'type': 'end_turn'});
      expect(end.any((e) => e['type'] == 'enemy_attacked'), isFalse);
      expect(sim.player['hp'], equals(hp0));
      // The next beat is the authored attack.
      expect(
        (sim.enemy!['intent'] as Map)['kind'],
        equals(enemies['cinder_urchin']!.pattern[1].kind),
      );
    });
  });

  group('roster integrity', () {
    test('new ids are registered, ordered, and layer-gated late', () {
      for (final id in ['vent_ram', 'cinder_urchin', 'magma_lancer']) {
        expect(enemiesOrder.contains(id), isTrue, reason: id);
        expect(enemies[id], isNotNull, reason: id);
        expect(enemies[id]!.fromLayer >= 5, isTrue,
            reason: '$id: response puzzles stay out of the early curve');
      }
      expect(enemies['magma_lancer']!.elite, isTrue);
    });
  });
}
