// test/face_forge_sim_test.dart — v7 run-local custom die foundation.

import 'dart:convert';

import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

Sim _atRest(int seed) {
  final sim = Sim(seed);
  sim.apply({'type': 'start_run', 'character': 'kindler'});
  // Isolate the rest command surface. Map generation/path legality is already
  // covered in sim_test; these tests own temper validation and persistence.
  sim.phase = 'rest';
  return sim;
}

Sim _inCombat({required String rune, int face = 3, String base = 'd6'}) {
  final sim = Sim(123)..apply({'type': 'start_run'});
  sim.run!['custom_dice'] = {
    'custom_1': {'base': base, 'face': face, 'rune': rune},
  };
  sim.player['dice'] = <String>['custom_1'];
  combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
  return sim;
}

Map<String, Object?> _temper(
  Sim sim, {
  int die = 1,
  int face = 6,
  String rune = 'blade',
}) => {'type': 'temper_face', 'die': die, 'face': face, 'rune': rune};

void main() {
  group('v7 face temper foundation', () {
    test('new runs initialize a JSON-safe custom-die ledger', () {
      final sim = Sim(1)..apply({'type': 'start_run'});
      expect(sim.version, simVersion);
      expect(simVersion, 7);
      expect(sim.run!['custom_dice'], isEmpty);
      expect(sim.run!['next_custom_die'], 1);
      expect(sim.run!['tempers_used'], 0);
      expect(sim.run!['keystones'], isEmpty);
      expect(() => jsonEncode(sim.snapshot()), returnsNormally);
    });

    test(
      'temper validates phase, index, rune and natural face before mutation',
      () {
        final wrongPhase = Sim(1)..apply({'type': 'start_run'});
        final before = wrongPhase.stateHash();
        expect(wrongPhase.apply(_temper(wrongPhase)).single, {
          'type': 'invalid_command',
          'reason': 'not_rest_phase',
        });
        expect(wrongPhase.stateHash(), before);

        for (final entry in <(Map<String, Object?>, String)>[
          (_temper(_atRest(2), die: 0), 'no_such_die'),
          (_temper(_atRest(2), die: 99), 'no_such_die'),
          (_temper(_atRest(2), face: 0), 'no_such_face'),
          (_temper(_atRest(2), face: 7), 'no_such_face'),
          (_temper(_atRest(2), rune: 'unknown'), 'unknown_rune'),
        ]) {
          final sim = _atRest(2);
          final cmd = Map<String, Object?>.from(entry.$1);
          final hash = sim.stateHash();
          final events = sim.apply(cmd);
          expect(events.single['reason'], entry.$2, reason: '$cmd');
          expect(sim.stateHash(), hash, reason: '$cmd mutated state');
          expect(sim.run!['custom_dice'], isEmpty);
        }
      },
    );

    test('one temper creates a stable run-local id and one flat event', () {
      final sim = _atRest(11);
      final events = sim.apply(_temper(sim, face: 4, rune: 'echo'));

      expect(events, [
        {
          'type': 'face_tempered',
          'die': 1,
          'custom': 'custom_1',
          'base': 'd6',
          'face': 4,
          'rune': 'echo',
        },
      ]);
      expect(
        events.single.values.every((v) => v is String || v is int),
        isTrue,
      );
      expect((sim.player['dice'] as List).first, 'custom_1');
      expect(sim.run!['custom_dice'], {
        'custom_1': {'base': 'd6', 'face': 4, 'rune': 'echo'},
      });
      expect(sim.run!['next_custom_die'], 2);
      expect(sim.run!['tempers_used'], 1);
      expect(sim.phase, 'map');

      final die = resolveRunDie(sim.run, 'custom_1');
      expect(die.baseId, 'd6');
      expect(die.def.size, 6);
      expect(die.temperedFace, 4);
      expect(die.rune, 'echo');
    });

    test('one-per-run cap rejects a second temper without mutation', () {
      final sim = _atRest(12);
      sim.apply(_temper(sim));
      sim.phase = 'rest';
      final before = sim.stateHash();
      final events = sim.apply(_temper(sim, die: 2, rune: 'aegis'));
      expect(events.single, {
        'type': 'invalid_command',
        'reason': 'temper_used',
      });
      expect(sim.stateHash(), before);
      expect(sim.run!['custom_dice'], hasLength(1));
      expect(sim.run!['next_custom_die'], 2);
    });

    test('size forge preserves custom identity, face and rune', () {
      final sim = _atRest(13);
      sim.apply(_temper(sim, face: 6, rune: 'blade'));
      sim.phase = 'rest';
      final events = sim.apply({'type': 'forge', 'die': 1, 'into': 'd8'});

      expect(events.single, {
        'type': 'forged',
        'from': 'd6',
        'into': 'd8',
        'custom': 'custom_1',
      });
      expect((sim.player['dice'] as List).first, 'custom_1');
      final die = resolveRunDie(sim.run, 'custom_1');
      expect(die.baseId, 'd8');
      expect(die.def.size, 8);
      expect(die.temperedFace, 6);
      expect(die.rune, 'blade');
    });

    test(
      'JSON snapshot/restore preserves custom identity and future replay',
      () {
        final original = _atRest(14);
        original.apply(_temper(original, face: 3, rune: 'surge'));
        final wire =
            jsonDecode(jsonEncode(original.snapshot())) as Map<String, dynamic>;
        final twin = Sim.restore(wire);

        expect(twin.snapshot(), original.snapshot());
        expect(twin.stateHash(), original.stateHash());
        expect(resolveRunDie(twin.run, 'custom_1').rune, 'surge');

        original.phase = 'rest';
        twin.phase = 'rest';
        final cmd = {'type': 'forge', 'die': 1, 'into': 'd8'};
        expect(twin.apply(cmd), original.apply(cmd));
        expect(twin.snapshot(), original.snapshot());
        expect(twin.stateHash(), original.stateHash());
        expect(twin.eventHash, original.eventHash);
      },
    );

    test('same seed and commands yield identical IDs, events and hashes', () {
      final a = _atRest(99);
      final b = _atRest(99);
      final cmd = _temper(a, face: 2, rune: 'aegis');
      expect(a.apply(cmd), b.apply(cmd));
      expect(a.snapshot(), b.snapshot());
      expect(a.stateHash(), b.stateHash());
      expect(a.eventHash, b.eventHash);
    });

    test('Blade/Aegis use the natural face and exact action only', () {
      final blade = _inCombat(rune: 'blade');
      blade.player['rolled'] = <int>[3];
      blade.player['rolled_face'] = <int>[3];
      blade.player['rolled_max'] = <bool>[false];
      blade.player['combo_bonus'] = <int>[0];
      final beforeHp = blade.enemy!['hp'] as int;
      final attack = blade.apply({
        'type': 'assign',
        'die': 1,
        'action': 'attack',
      });
      expect(attack.where((e) => e['type'] == 'rune_triggered').single, {
        'type': 'rune_triggered',
        'die': 1,
        'rune': 'blade',
        'face': 3,
      });
      expect(attack.where((e) => e['type'] == 'rune_bonus').single, {
        'type': 'rune_bonus',
        'die': 1,
        'action': 'attack',
        'amount': 2,
      });
      expect(
        attack.where((e) => e['type'] == 'die_assigned').single['value'],
        5,
      );
      expect(blade.enemy!['hp'], beforeHp - 5);

      final wrongVerb = _inCombat(rune: 'blade');
      wrongVerb.player['rolled'] = <int>[3];
      wrongVerb.player['rolled_face'] = <int>[3];
      wrongVerb.player['rolled_max'] = <bool>[false];
      wrongVerb.player['combo_bonus'] = <int>[0];
      final block = wrongVerb.apply({
        'type': 'assign',
        'die': 1,
        'action': 'block',
      });
      expect(block.where((e) => e['type'] == 'rune_triggered'), isEmpty);
      expect(block.where((e) => e['type'] == 'rune_bonus'), isEmpty);
      expect(
        block.where((e) => e['type'] == 'die_assigned').single['value'],
        3,
      );

      final aegis = _inCombat(rune: 'aegis');
      aegis.player['rolled'] = <int>[3];
      aegis.player['rolled_face'] = <int>[3];
      aegis.player['rolled_max'] = <bool>[false];
      aegis.player['combo_bonus'] = <int>[0];
      final guarded = aegis.apply({
        'type': 'assign',
        'die': 1,
        'action': 'block',
      });
      expect(
        guarded.where((e) => e['type'] == 'die_assigned').single['value'],
        5,
      );
    });

    test('resolved floors cannot fake a natural face rune match', () {
      final sim = _inCombat(rune: 'blade', face: 3, base: 'd6_steady');
      // Steady Ember resolves natural 1 to value 3. The tempered face is 3,
      // but rolled_face remains 1, so Blade must not trigger.
      sim.player['rolled'] = <int>[3];
      sim.player['rolled_face'] = <int>[1];
      sim.player['rolled_max'] = <bool>[false];
      sim.player['combo_bonus'] = <int>[0];
      final events = sim.apply({
        'type': 'assign',
        'die': 1,
        'action': 'attack',
      });
      expect(events.where((e) => e['type'] == 'rune_triggered'), isEmpty);
      expect(
        events.where((e) => e['type'] == 'die_assigned').single['value'],
        3,
      );
    });
  });
}
