// test/keystone_sim_test.dart — v7 keystones: effects, acquisition, and the
// preview/resolution parity that the contract makes non-negotiable.
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/keystones.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fight with a fixed pool and a fixed roll, so every assertion is about the
/// keystone arithmetic and nothing else.
Sim _fight({
  required List<String> keystones,
  List<String> pool = const ['d6', 'd6', 'd6'],
  List<int> rolled = const [3, 3, 3],
}) {
  final sim = Sim(123)..apply({'type': 'start_run'});
  sim.run!['keystones'] = List<String>.from(keystones);
  sim.player['dice'] = List<String>.from(pool);
  combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
  sim.player['rolled'] = List<int>.from(rolled);
  sim.player['rolled_face'] = List<int>.from(rolled);
  sim.player['rolled_max'] = List<bool>.filled(rolled.length, false);
  sim.player['combo_bonus'] = List<int>.filled(rolled.length, 0);
  sim.player['assigned'] = <String, String>{};
  return sim;
}

int _assignedValue(List<Map<String, Object?>> events) =>
    events.firstWhere((e) => e['type'] == 'die_assigned')['value'] as int;

Iterable<Map<String, Object?>> _hits(
  List<Map<String, Object?>> events,
  String keystone,
) => events.where(
  (e) => e['type'] == 'keystone_triggered' && e['keystone'] == keystone,
);

void main() {
  group('ashen_edge', () {
    test('pays for every other unspent die, once per turn', () {
      final sim = _fight(keystones: ['ashen_edge']);
      // Two other dice still unspent -> 3 + 2.
      final first = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(_assignedValue(first), 5);
      expect(_hits(first, 'ashen_edge').single['amount'], 2);
      expect(_hits(first, 'ashen_edge').single['die'], 1);

      // Second attack in the same turn pays nothing extra.
      final second = sim.apply({
        'type': 'assign',
        'die': 2,
        'action': 'attack',
      });
      expect(_assignedValue(second), 3);
      expect(_hits(second, 'ashen_edge'), isEmpty);
    });

    test('a block assignment neither pays nor burns the charge', () {
      final sim = _fight(keystones: ['ashen_edge']);
      final blocked = sim.apply({
        'type': 'assign',
        'die': 1,
        'action': 'block',
      });
      expect(_hits(blocked, 'ashen_edge'), isEmpty);
      expect(sim.player['ashen_used'], isFalse);
      final attack = sim.apply({
        'type': 'assign',
        'die': 2,
        'action': 'attack',
      });
      expect(_hits(attack, 'ashen_edge').single['amount'], 1);
    });

    test('the last die alone pays nothing — it never counts itself', () {
      final sim = _fight(keystones: ['ashen_edge'], pool: ['d6'], rolled: [4]);
      final events = sim.apply({
        'type': 'assign',
        'die': 1,
        'action': 'attack',
      });
      expect(_assignedValue(events), 4);
      expect(_hits(events, 'ashen_edge'), isEmpty);
    });

    test('the charge returns next turn', () {
      final sim = _fight(keystones: ['ashen_edge']);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(sim.player['ashen_used'], isTrue);
      sim.apply({'type': 'end_turn'});
      expect(sim.player['ashen_used'], isFalse);
    });
  });

  group('living_bastion', () {
    test('carries half the UNUSED block, floored and capped at 8', () {
      final sim = _fight(keystones: ['living_bastion']);
      sim.player['block'] = 7;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 2};
      final events = sim.apply({'type': 'end_turn'});
      // 7 block, 2 spent on the shown intent -> 5 unused -> 2 carried.
      expect(sim.player['block'], 2);
      expect(_hits(events, 'living_bastion').single['amount'], 2);
    });

    test('caps the carry at 8 no matter how large the wall was', () {
      final sim = _fight(keystones: ['living_bastion']);
      sim.player['block'] = 40;
      sim.enemy!['intent'] = {'kind': 'block', 'amount': 3};
      sim.apply({'type': 'end_turn'});
      expect(sim.player['block'], 8);
    });

    test('without the keystone the wall still falls to zero', () {
      final sim = _fight(keystones: const []);
      sim.player['block'] = 12;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 2};
      final events = sim.apply({'type': 'end_turn'});
      expect(sim.player['block'], 0);
      expect(events.where((e) => e['type'] == 'keystone_triggered'), isEmpty);
    });
  });

  group('crown_of_twelve', () {
    test('pays for each EXTRA die size used this turn', () {
      final sim = _fight(
        keystones: ['crown_of_twelve'],
        pool: ['d6', 'd8', 'd10'],
        rolled: [3, 3, 3],
      );
      expect(
        _assignedValue(
          sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'}),
        ),
        3, // one size so far: +0
      );
      expect(
        _assignedValue(
          sim.apply({'type': 'assign', 'die': 2, 'action': 'attack'}),
        ),
        4, // two distinct sizes: +1
      );
      expect(
        _assignedValue(
          sim.apply({'type': 'assign', 'die': 3, 'action': 'attack'}),
        ),
        5, // three distinct sizes: +2
      );
    });

    test('repeating a size pays nothing new', () {
      final sim = _fight(
        keystones: ['crown_of_twelve'],
        pool: ['d6', 'd6'],
        rolled: [3, 3],
      );
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      final second = sim.apply({'type': 'assign', 'die': 2, 'action': 'block'});
      expect(_assignedValue(second), 3);
      expect(_hits(second, 'crown_of_twelve'), isEmpty);
    });
  });

  group('twin_bellows', () {
    test('alternating pays 1, 2, then 3 and holds the cap', () {
      final sim = _fight(
        keystones: ['twin_bellows'],
        pool: ['d6', 'd6', 'd6', 'd6', 'd6'],
        rolled: [3, 3, 3, 3, 3],
      );
      final values = <int>[];
      const verbs = ['attack', 'block', 'attack', 'block', 'attack'];
      for (var i = 0; i < verbs.length; i++) {
        values.add(
          _assignedValue(
            sim.apply({'type': 'assign', 'die': i + 1, 'action': verbs[i]}),
          ),
        );
      }
      expect(values, [3, 4, 5, 6, 6]);
    });

    test('repeating a verb breaks the chain back to zero', () {
      final sim = _fight(
        keystones: ['twin_bellows'],
        pool: ['d6', 'd6', 'd6'],
        rolled: [3, 3, 3],
      );
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(
        _assignedValue(
          sim.apply({'type': 'assign', 'die': 2, 'action': 'block'}),
        ),
        4,
      );
      final repeat = sim.apply({'type': 'assign', 'die': 3, 'action': 'block'});
      expect(_assignedValue(repeat), 3);
      expect(sim.player['bellows_streak'], 0);
    });

    test('the chain does not survive the turn', () {
      final sim = _fight(keystones: ['twin_bellows']);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      sim.apply({'type': 'end_turn'});
      expect(sim.player['bellows_action'], isNull);
      expect(sim.player['bellows_streak'], 0);
    });
  });

  group('preview parity and stacking', () {
    test('preview equals the emitted value with three keystones live', () {
      final sim = _fight(
        keystones: ['ashen_edge', 'crown_of_twelve', 'twin_bellows'],
        pool: ['d6', 'd8', 'd10'],
        rolled: [3, 4, 5],
      );
      sim.apply({'type': 'assign', 'die': 1, 'action': 'block'});
      final preview = resolveAssignment(
        player: sim.player,
        enemy: sim.enemy!,
        run: sim.run,
        die: 2,
        action: 'attack',
      );
      final events = sim.apply({
        'type': 'assign',
        'die': 2,
        'action': 'attack',
      });
      expect(_assignedValue(events), preview.value);
      // 4 roll + 1 unspent die (ashen) + 1 extra size (crown) + 1 alternation.
      expect(preview.value, 7);
      expect(preview.keystoneHits.length, 3);
    });
  });

  group('acquisition', () {
    test('the first won fight offers three keystones, then the reward', () {
      final sim = Sim(7)..apply({'type': 'start_run'});
      final events = <Map<String, Object?>>[];
      sim.map = {
        'nodes': {
          '1': {
            'id': 1,
            'layer': 2,
            'kind': 'fight',
            'offers': <String>['d8'],
          },
        },
        'position': 1,
      };
      combatBegin(sim, 'cinder_wisp', false, events, layer: 2);
      sim.apply({'type': 'roll'});
      sim.enemy!['hp'] = 1;
      final won = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(won.any((e) => e['type'] == 'keystone_offered'), isTrue);
      expect(sim.phase, 'keystone');
      final offered = sim.keystoneOffers!;
      expect(offered.length, 3);
      expect(offered.toSet().length, 3, reason: 'no duplicate cards');
      expect(offered.every(keystones.containsKey), isTrue);

      final taken = sim.apply({'type': 'choose_keystone', 'index': 1});
      expect(
        taken.firstWhere((e) => e['type'] == 'keystone_taken')['keystone'],
        offered[0],
      );
      expect(sim.run!['keystones'], [offered[0]]);
      // The fight's die reward follows immediately — the pick never eats it.
      expect(sim.phase, 'reward');
      expect(taken.any((e) => e['type'] == 'reward_offered'), isTrue);
    });

    test('declining is allowed and still pays the reward', () {
      final sim = Sim(11)..apply({'type': 'start_run'});
      sim.map = {
        'nodes': {
          '1': {
            'id': 1,
            'layer': 2,
            'kind': 'fight',
            'offers': <String>['d8'],
          },
        },
        'position': 1,
      };
      combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
      sim.enemy!['hp'] = 1;
      sim.apply({'type': 'roll'});
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(sim.phase, 'keystone');
      final events = sim.apply({'type': 'choose_keystone', 'index': 0});
      expect(events.any((e) => e['type'] == 'keystone_declined'), isTrue);
      expect(sim.run!['keystones'], isEmpty);
      expect(sim.phase, 'reward');
    });

    test('only one offering per run', () {
      final sim = Sim(11)..apply({'type': 'start_run'});
      sim.map = {
        'nodes': {
          '1': {
            'id': 1,
            'layer': 2,
            'kind': 'fight',
            'offers': <String>['d8'],
          },
        },
        'position': 1,
      };
      for (var fight = 0; fight < 2; fight++) {
        combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
        sim.enemy!['hp'] = 1;
        sim.apply({'type': 'roll'});
        sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
        if (fight == 0) {
          expect(sim.phase, 'keystone');
          sim.apply({'type': 'choose_keystone', 'index': 1});
        }
        expect(sim.phase, 'reward');
      }
      expect((sim.run!['keystones'] as List).length, 1);
    });

    test('choose_keystone outside the phase is rejected without mutation', () {
      final sim = Sim(3)..apply({'type': 'start_run'});
      final events = sim.apply({'type': 'choose_keystone', 'index': 1});
      expect(events.single, {
        'type': 'invalid_command',
        'reason': 'not_keystone_phase',
      });
      expect(sim.run!['keystones'], isEmpty);
    });

    test('offers and picks survive a snapshot round trip', () {
      final sim = Sim(11)..apply({'type': 'start_run'});
      sim.map = {
        'nodes': {
          '1': {
            'id': 1,
            'layer': 2,
            'kind': 'fight',
            'offers': <String>['d8'],
          },
        },
        'position': 1,
      };
      combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
      sim.enemy!['hp'] = 1;
      sim.apply({'type': 'roll'});
      sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      expect(sim.phase, 'keystone');

      final resumed = Sim.restore(Map<String, dynamic>.from(sim.snapshot()));
      expect(resumed.keystoneOffers, sim.keystoneOffers);
      expect(resumed.stateHash(), sim.stateHash());
      resumed.apply({'type': 'choose_keystone', 'index': 2});
      expect(resumed.run!['keystones'], [sim.keystoneOffers![1]]);
    });
  });
}
