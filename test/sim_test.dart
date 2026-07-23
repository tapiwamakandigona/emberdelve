// test/sim_test.dart — core sim determinism, rules, persistence, golden anchor.
// Runs headless under `flutter test`. The sim is pure Dart (no Flutter imports)
// so these assertions also hold on any Dart VM.

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/sim/rng.dart';
import 'package:emberdelve/sim/autoplay.dart';

// The v3 golden, re-anchored after the balance pass (see progress.md).
// If this changes, sim behavior for existing seeds changed: bump SIM_VERSION
// and document. Kept in sync with test/autoplay_test.dart.
const int goldenV3 = 513683311;

void main() {
  group('rng', () {
    test('die rolls stay in bounds and hit all faces', () {
      final r = Rng.create(42, 'combat');
      final seen = <int>{};
      for (var i = 0; i < 5000; i++) {
        final v = r.die(6);
        expect(v >= 1 && v <= 6, isTrue);
        seen.add(v);
      }
      expect(seen, containsAll([1, 2, 3, 4, 5, 6]));
    });

    test('streams are independent', () {
      final a = Rng.create(7, 'map');
      final b = Rng.create(7, 'combat');
      // Consuming one does not shift the other.
      final b0 = Rng.create(7, 'combat');
      a.nextRaw();
      a.nextRaw();
      expect(b.nextRaw(), equals(b0.nextRaw()));
    });

    test('snapshot/restore continues identically', () {
      final r = Rng.create(99, 'loot');
      for (var i = 0; i < 10; i++) {
        r.nextRaw();
      }
      final twin = Rng.restore(r.snapshot());
      for (var i = 0; i < 10; i++) {
        expect(twin.nextRaw(), equals(r.nextRaw()));
      }
    });
  });

  group('determinism', () {
    test('same seed + same commands => identical event and state hashes', () {
      final a = playRun(12345).sim;
      final b = playRun(12345).sim;
      expect(a.eventHash, equals(b.eventHash));
      expect(a.stateHash(), equals(b.stateHash()));
    });

    test('different seeds => different runs', () {
      expect(playRun(1).sim.eventHash, isNot(equals(playRun(2).sim.eventHash)));
    });

    test('snapshot mid-run, restore, continue => identical', () {
      for (var seed = 1; seed <= 15; seed++) {
        final plain = playRun(seed).sim;
        final resumed = playRun(seed, snapAt: 30).sim;
        expect(resumed.eventHash, equals(plain.eventHash),
            reason: 'seed $seed event hash');
        expect(resumed.stateHash(), equals(plain.stateHash()),
            reason: 'seed $seed state hash');
      }
    });

    test('restore rejects a stale-version snapshot', () {
      final snap = Sim(1).snapshot();
      snap['version'] = 999;
      expect(() => Sim.restore(snap), throwsStateError);
    });

    test('golden determinism anchor (regression guard)', () {
      final sim = playRun(20260723).sim;
      expect(sim.eventHash, equals(goldenV3));
    });
  });

  group('rules', () {
    test('start_run builds map, ledger, and map phase', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      expect(sim.phase, equals('map'));
      expect(sim.map, isNotNull);
      expect(sim.run!['gold'], equals(0));
      expect(sim.run!['embers'], equals(0));
      expect((sim.player['dice'] as List).length, equals(3));
    });

    test('choose_node accepts only edges of the current position', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      final evs = sim.apply({'type': 'choose_node', 'node': 999});
      expect(evs.single['type'], equals('invalid_command'));
      expect(sim.phase, equals('map'));
    });

    test('entering a fight auto-starts an encounter with visible intent', () {
      // find a seed whose start node leads to a fight
      for (var seed = 1; seed <= 200; seed++) {
        final sim = Sim(seed);
        sim.apply({'type': 'start_run'});
        final start = sim.map!['position'] as int;
        final edges =
            ((sim.map!['edges'] as Map)['$start'] as List).cast<int>();
        int? fight;
        for (final e in edges) {
          if ((sim.map!['nodes'] as Map)['$e']!['kind'] == 'fight') {
            fight = e;
            break;
          }
        }
        if (fight == null) continue;
        final evs = sim.apply({'type': 'choose_node', 'node': fight});
        expect(sim.phase, equals('player_turn'));
        expect(evs.any((e) => e['type'] == 'encounter_started'), isTrue);
        expect(evs.any((e) => e['type'] == 'intent_shown'), isTrue);
        return;
      }
      fail('no fight-adjacent start node found');
    });

    test('invalid commands emit an event but never mutate state', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      final before = sim.stateHash();
      final evs = sim.apply({'type': 'roll'}); // not in combat
      expect(evs.single['type'], equals('invalid_command'));
      expect(sim.stateHash(), equals(before));
    });

    test('full run reaches a terminal phase with a consistent ledger', () {
      for (var seed = 1; seed <= 30; seed++) {
        final r = playRun(seed);
        expect(['run_won', 'run_lost'].contains(r.sim.phase), isTrue,
            reason: 'seed $seed ended at ${r.sim.phase}');
        expect(r.invalids, equals(0), reason: 'seed $seed invalids');
        expect(r.sim.run!['embers'] >= 0, isTrue);
        expect(r.sim.run!['gold'] >= 0, isTrue);
      }
    });
  });
}
