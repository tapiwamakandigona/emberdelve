// test/map_test.dart — property tests over the map generator (200 seeds).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/sim/rng.dart';
import 'package:emberdelve/sim/map_gen.dart';

void main() {
  group('map generation properties', () {
    test('connectivity, reachability, guarantees over 200 seeds', () {
      for (var seed = 1; seed <= 200; seed++) {
        final map = generateMap(Rng.create(seed, 'map'));
        final nodes = (map['nodes'] as Map).cast<String, Map>();
        final edges = (map['edges'] as Map).cast<String, List>();
        final start = map['start'] as int;
        final boss = map['boss'] as int;
        final layers = map['layers'] as int;

        expect(nodes['$start']!['kind'], equals('start'));
        expect(nodes['$boss']!['kind'], equals('boss'));

        // every non-boss node has >=1 forward edge; edges span exactly 1 layer
        for (final entry in nodes.entries) {
          final id = int.parse(entry.key);
          final layer = entry.value['layer'] as int;
          final out = edges['$id']!.cast<int>();
          if (id != boss) {
            expect(out.isNotEmpty, isTrue, reason: 'seed $seed node $id no edge');
          }
          for (final t in out) {
            expect(nodes['$t']!['layer'], equals(layer + 1),
                reason: 'seed $seed edge crosses >1 layer');
          }
        }

        // forward reachability from start reaches boss + all nodes
        final reached = <int>{start};
        final queue = <int>[start];
        while (queue.isNotEmpty) {
          final n = queue.removeLast();
          for (final t in edges['$n']!.cast<int>()) {
            if (reached.add(t)) queue.add(t);
          }
        }
        expect(reached.contains(boss), isTrue,
            reason: 'seed $seed boss unreachable');
        expect(reached.length, equals(nodes.length),
            reason: 'seed $seed unreachable nodes');

        // boss reachable from EVERY node (reverse BFS)
        final parents = <int, List<int>>{};
        for (final id in nodes.keys) {
          parents[int.parse(id)] = [];
        }
        edges.forEach((k, v) {
          for (final t in v.cast<int>()) {
            parents[t]!.add(int.parse(k));
          }
        });
        final canReachBoss = <int>{boss};
        final q2 = <int>[boss];
        while (q2.isNotEmpty) {
          final n = q2.removeLast();
          for (final p in parents[n]!) {
            if (canReachBoss.add(p)) q2.add(p);
          }
        }
        expect(canReachBoss.length, equals(nodes.length),
            reason: 'seed $seed dead end exists');

        // guarantees: >=1 elite, >=1 rest (late), >=1 shop; no adjacent rests
        var elites = 0, lateRests = 0, shops = 0;
        for (final entry in nodes.entries) {
          final kind = entry.value['kind'];
          final layer = entry.value['layer'] as int;
          if (kind == 'elite') elites++;
          if (kind == 'rest' && layer >= 6) lateRests++;
          if (kind == 'shop') shops++;
        }
        expect(elites >= 1, isTrue, reason: 'seed $seed no elite');
        expect(lateRests >= 1, isTrue, reason: 'seed $seed no late rest');
        expect(shops >= 1, isTrue, reason: 'seed $seed no shop');

        // no rest -> rest edge
        edges.forEach((k, v) {
          if (nodes[k]!['kind'] == 'rest') {
            for (final t in v.cast<int>()) {
              expect(nodes['$t']!['kind'], isNot(equals('rest')),
                  reason: 'seed $seed adjacent rests');
            }
          }
        });

        expect(layers, greaterThanOrEqualTo(3));
      }
    });

    test('same rng state + cfg => identical map', () {
      final a = generateMap(Rng.create(5, 'map'));
      final b = generateMap(Rng.create(5, 'map'));
      expect(a.toString(), equals(b.toString()));
    });
  });
}
