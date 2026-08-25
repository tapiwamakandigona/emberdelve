// test/shorter_road_test.dart — v0.49.0 The Shorter Road.
//
// The Short Delve: a 4th mutator (`short_road`) that generates a six-layer
// map (map_gen.shortRoadCfg) and compresses the run to fit — reward tiers
// read three floors deep, fight gold runs x1.5, and the heaviest foes are
// shaved (elites -2 / HP x0.80, boss -3 / HP x0.58) because they stand
// floors earlier than the long delve tuned them for. All knobs were tuned
// by 400-seed sweeps until the fairness bands held on the short format
// (easy 87.5 / normal 56.0 / hard 32.75 at tuning time — see
// docs/improvements/v0.49.0-shorter-road-design.md).
//
// Guardrails here:
//   1. Catalog + trial wiring (Short Day rides the daily seam).
//   2. Map shape: 6 layers, boss at 6, guarantees hold, rests never adjacent.
//   3. Combat shave: boss/elite only, normal runs byte-untouched (goldens in
//      sim_test.dart remain the anchor for the default format).
//   4. Reward arc: tier-3 dice reachable before the short boss.
//   5. Determinism, save/restore, and pinned outcomes.
//   6. Delve Codes carry the format in bit 44; old codes round-trip as 0.
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/data/trials.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

Sim _started(int seed, {List<String> mutators = const [], String? difficulty}) {
  final sim = Sim(seed);
  sim.apply({
    'type': 'start_run',
    'character': 'kindler',
    'ascension': 0,
    if (difficulty != null) 'difficulty': difficulty,
    if (mutators.isNotEmpty) 'mutators': mutators,
  });
  return sim;
}

Map<int, Map> _nodes(Sim sim) => {
  for (final e in (sim.map!['nodes'] as Map).entries)
    int.parse('${e.key}'): e.value as Map,
};

void main() {
  group('catalog and trial wiring', () {
    test('short_road is a known mutator, appended to the order', () {
      expect(isKnownMutator('short_road'), isTrue);
      expect(mutatorsOrder.last, equals('short_road'));
      expect(mutatorDef('short_road').name, equals('Short Road'));
      expect(mutatorDef('short_road').blurb, isNotEmpty);
    });

    test('Short Day trial rides the existing daily mutator seam', () {
      expect(trialsOrder, contains('short_day'));
      final t = trialDef('short_day');
      expect(t.mutators, equals(['short_road']));
      expect(t.goalId, isEmpty);
      expect(t.emberBonus, equals(0));
    });
  });

  group('map shape', () {
    test('six layers, boss on 6, all guarantees hold (seeds 1..40)', () {
      for (var seed = 1; seed <= 40; seed++) {
        final sim = _started(seed, mutators: ['short_road']);
        final map = sim.map!;
        expect(map['layers'], equals(6), reason: 'seed $seed layers');
        final nodes = _nodes(sim);
        final edges = (map['edges'] as Map).cast<String, List>();
        final boss = nodes[map['boss'] as int]!;
        expect(boss['kind'], equals('boss'));
        expect(boss['layer'], equals(6), reason: 'seed $seed boss layer');
        // Guarantees: >=1 elite (never before layer 4), >=1 rest, >=1 shop.
        final kinds = <String, List<int>>{};
        nodes.forEach((id, n) {
          kinds.putIfAbsent(n['kind'] as String, () => []).add(id);
        });
        expect(kinds['elite'], isNotEmpty, reason: 'seed $seed elite');
        for (final id in kinds['elite']!) {
          expect(
            nodes[id]!['layer'] as int,
            greaterThanOrEqualTo(4),
            reason: 'seed $seed elite on layer <4',
          );
        }
        expect(kinds['rest'], isNotEmpty, reason: 'seed $seed rest');
        expect(kinds['shop'], isNotEmpty, reason: 'seed $seed shop');
        // Rests never adjacent — the relaxed guarantee must keep the rule.
        for (final id in kinds['rest'] ?? const <int>[]) {
          for (final child in edges['$id'] ?? const []) {
            expect(
              nodes[child as int]!['kind'],
              isNot(equals('rest')),
              reason: 'seed $seed adjacent rests $id->$child',
            );
          }
        }
      }
    });

    test('without the mutator the map is the nine-layer classic', () {
      for (final seed in [1, 6, 20260723]) {
        expect(_started(seed).map!['layers'], equals(9));
      }
    });
  });

  group('combat shave (elites and boss only)', () {
    test('boss fights at HP x0.58 and -3 on the Short Road', () {
      final classic = _started(1);
      final short = _started(1, mutators: ['short_road']);
      final bossId = bossForSeed(1);
      final e1 = <Map<String, Object?>>[], e2 = <Map<String, Object?>>[];
      combatBegin(classic, bossId, false, e1);
      combatBegin(short, bossId, false, e2);
      final a = classic.enemy!, b = short.enemy!;
      expect(b['hp'], equals(((a['hp'] as int) * 0.58).round()));
      final pa = (a['pattern'] as List).cast<Map>();
      final pb = (b['pattern'] as List).cast<Map>();
      for (var i = 0; i < pa.length; i++) {
        final base = pa[i]['amount'] as int;
        final want = base - 3 < 1 ? 1 : base - 3;
        expect(pb[i]['amount'], equals(want), reason: 'pattern step $i');
      }
    });

    test('elites fight at HP x0.80 and -2; regulars are untouched', () {
      // An inherently-elite enemy and a plain regular, same layer (mercy off).
      final eliteId = enemiesOrder.firstWhere((id) => enemies[id]!.elite);
      final regularId = enemiesOrder.firstWhere(
        (id) => !enemies[id]!.elite && !enemies[id]!.boss,
      );
      final classic = _started(2);
      final short = _started(2, mutators: ['short_road']);
      final ev = <Map<String, Object?>>[];
      combatBegin(classic, eliteId, true, ev, layer: 5);
      combatBegin(short, eliteId, true, ev, layer: 5);
      // (combatBegin replaces sim.enemy — re-run pairwise for clean reads.)
      combatBegin(classic, eliteId, true, ev, layer: 5);
      final ce = Map<String, dynamic>.from(classic.enemy!);
      combatBegin(short, eliteId, true, ev, layer: 5);
      final se = Map<String, dynamic>.from(short.enemy!);
      expect(se['hp'], equals(((ce['hp'] as int) * 0.80).round()));
      final cp = (ce['pattern'] as List).cast<Map>();
      final sp = (se['pattern'] as List).cast<Map>();
      for (var i = 0; i < cp.length; i++) {
        final base = cp[i]['amount'] as int;
        final want = base - 2 < 1 ? 1 : base - 2;
        expect(sp[i]['amount'], equals(want));
      }
      // Regulars: identical with and without the mutator.
      combatBegin(classic, regularId, false, ev, layer: 4);
      final cr = Map<String, dynamic>.from(classic.enemy!);
      combatBegin(short, regularId, false, ev, layer: 4);
      final sr = Map<String, dynamic>.from(short.enemy!);
      expect(sr['hp'], equals(cr['hp']));
      expect(
        (sr['pattern'] as List).map((p) => (p as Map)['amount']).toList(),
        equals((cr['pattern'] as List).map((p) => (p as Map)['amount']).toList()),
      );
    });
  });

  group('compressed reward arc', () {
    test('plain fights can offer tier-3 dice before the short boss — the '
        'classic first six floors never do (elite rare guarantees aside)', () {
      // Elite nodes guarantee one rare on ANY map; the compressed arc claim
      // is about the plain fight pool, so only `fight` nodes are judged.
      var sawTier3 = false;
      for (var seed = 1; seed <= 20 && !sawTier3; seed++) {
        final sim = _started(seed, mutators: ['short_road']);
        for (final n in _nodes(sim).values) {
          if (n['kind'] != 'fight') continue;
          for (final d in (n['offers'] as List? ?? const []).cast<String>()) {
            if (dice[d]!.tier == 3) sawTier3 = true;
          }
        }
      }
      expect(sawTier3, isTrue, reason: 'no tier-3 fight offer in 20 short maps');
      // The classic arc is unchanged: fight nodes on layers <=6 never pool
      // tier 3 (the ceiling only opens at layer 7).
      for (var seed = 1; seed <= 20; seed++) {
        final sim = _started(seed);
        for (final n in _nodes(sim).values) {
          if (n['kind'] != 'fight' || (n['layer'] as int) > 6) continue;
          for (final d in (n['offers'] as List? ?? const []).cast<String>()) {
            expect(dice[d]!.tier, lessThan(3), reason: 'seed $seed classic');
          }
        }
      }
    });

    test('fight gold pays x1.5 on the Short Road (kindler, no gold relic)', () {
      // First won fight of a short run: base roll 12..22 becomes 18..33 and
      // always equals round(g * 1.5) for an integer g.
      final valid = {for (var g = 12; g <= 22; g++) (g * 1.5).round()};
      var checked = 0;
      // Easy difficulty so early losses don't starve the sample; a seed is
      // skipped once any relic lands (a gold_bonus relic would shift the
      // amount honestly and prove nothing about the x1.5).
      for (var seed = 1; seed <= 12; seed++) {
        var sim = Sim(seed);
        var guard = 0, relic = false;
        while (guard++ < 600) {
          final cmd = botCmd(
            sim,
            difficulty: 'easy',
            mutators: const ['short_road'],
          );
          if (cmd == null) break;
          final events = sim.apply(cmd);
          if (events.any((e) => e['type'] == 'relic_gained')) relic = true;
          final gold = events.where(
            (e) => e['type'] == 'gold_gained' && e['source'] == 'fight',
          );
          if (gold.isNotEmpty) {
            if (!relic) {
              expect(
                valid,
                contains(gold.first['amount']),
                reason: 'seed $seed fight gold ${gold.first['amount']}',
              );
              checked++;
            }
            break;
          }
        }
      }
      expect(checked, greaterThanOrEqualTo(4));
    });
  });

  group('determinism, restore, and pinned outcomes', () {
    test('same seed, same short delve; mid-run restore keeps the format', () {
      final plain = playRun(6, mutators: const ['short_road']);
      expect(
        playRun(6, mutators: const ['short_road']).sim.eventHash,
        equals(plain.sim.eventHash),
      );
      final resumed = playRun(6, mutators: const ['short_road'], snapAt: 15);
      expect(resumed.sim.eventHash, equals(plain.sim.eventHash));
      expect(resumed.sim.mutators, equals({'short_road'}));
      expect(resumed.sim.map!['layers'], equals(6));
    });

    test('pinned outcomes: kindler seed 6 wins normal, seed 1 wins easy and '
        'falls on normal', () {
      expect(
        playRun(6, mutators: const ['short_road']).sim.phase,
        equals('run_won'),
      );
      final easy = playRun(
        1,
        difficulty: 'easy',
        mutators: const ['short_road'],
      );
      expect(easy.sim.phase, equals('run_won'));
      expect(easy.invalids, equals(0));
      expect(
        playRun(1, mutators: const ['short_road']).sim.phase,
        equals('run_lost'),
      );
    });
  });

  group('delve codes carry the format', () {
    test('bit 44 round-trips; classic codes decode with shortRoad false', () {
      final short = encodeDelveCode(
        seed: 987654,
        character: 'kindler',
        difficulty: 'hard',
        ascension: 7,
        shortRoad: true,
      )!;
      final classic = encodeDelveCode(
        seed: 987654,
        character: 'kindler',
        difficulty: 'hard',
        ascension: 7,
      )!;
      expect(short, isNot(equals(classic)));
      final ds = decodeDelveCode(short)!;
      expect(ds.shortRoad, isTrue);
      expect(ds.seed, equals(987654));
      expect(ds.character, equals('kindler'));
      expect(ds.difficulty, equals('hard'));
      expect(ds.ascension, equals(7));
      final dc = decodeDelveCode(classic)!;
      expect(dc.shortRoad, isFalse);
      expect(dc.seed, equals(987654));
      // Typos still fail politely.
      expect(decodeDelveCode(short.replaceRange(6, 7, short[6] == 'A' ? 'B' : 'A')),
          isNull);
    });
  });
}
