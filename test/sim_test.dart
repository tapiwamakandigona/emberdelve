// test/sim_test.dart — core sim determinism, rules, persistence, golden anchor.
// Runs headless under `flutter test`. The sim is pure Dart (no Flutter imports)
// so these assertions also hold on any Dart VM.

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/boons.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/sim/combos.dart';
import 'package:emberdelve/sim/daily.dart';
import 'package:emberdelve/sim/rng.dart';
import 'package:emberdelve/sim/autoplay.dart';

// The v6 golden, deliberately re-anchored when the starting-boon pool grew
// from 8 to 15 (the without-replacement draw over boonsOrder reshuffles the
// seeded boon stream for every seed; SIM_VERSION 5 -> 6 so mid-flight v5
// saves are cleanly discarded at boot). Resolution rules are untouched —
// only the offering stream moved. Old goldens: v3 513683311,
// v4 1117081416, v5 1117081416 (docs/m4-sim-contract.md documents v3->v4,
// docs/FIX_PLAN_v0.3.1.md v4->v5, progress.md the v5->v6 move). If this
// changes again, sim behavior for existing seeds changed: bump SIM_VERSION
// and document.
const int goldenV6 = 1842571558;

// v0.4 boss-variety anchors: one golden per boss (the V6 seed maps to the
// Tyrant; these two cover the Colossus and the Matriarch). Measured on the
// build that introduced boss variety (bin/autoplay-verified balance).
const int goldenColossus = 578589309;
const int goldenMatriarch = 1077392826;

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
      // Seed 20260723 % 3 == 1 maps to the Ember Tyrant (boss ordering in
      // enemiesOrder is deliberate), so this anchor survived the v0.4
      // boss-variety change byte-for-byte: boss choice is a pure function of
      // the seed and consumes no RNG stream.
      final sim = playRun(20260723).sim;
      expect(sim.eventHash, equals(goldenV6));
    });

    test('boss variety: seed picks the boss, each has its own anchor', () {
      // One anchor per boss so a regression in ANY boss fight trips the gate.
      expect(bossForSeed(20260723), equals('ember_tyrant'));
      expect(bossForSeed(20260724), equals('pyre_matriarch'));
      expect(bossForSeed(20260725), equals('ashen_colossus'));
      expect(playRun(20260724).sim.eventHash, equals(goldenMatriarch));
      expect(playRun(20260725).sim.eventHash, equals(goldenColossus));
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

  group('combos (v4) — pure function of the pool', () {
    test('pair: exactly two equal values give +1 each (+2 total)', () {
      final c = detectCombos([5, 5, 3]);
      expect(c.pairs.length, equals(1));
      expect(c.pairs[0].value, equals(5));
      expect(c.pairs[0].dice, equals([1, 2]));
      expect(c.bonus, equals([1, 1, 0]));
      expect(c.hasTriple, isFalse);
    });

    test('triple: three+ equal values ignite (no pair bonus)', () {
      final c = detectCombos([4, 4, 4]);
      expect(c.hasTriple, isTrue);
      expect(c.triples[0].value, equals(4));
      expect(c.pairs, isEmpty);
      expect(c.bonus, equals([0, 0, 0]));
    });

    test('straight: 3+ consecutive values detected, pairs coexist', () {
      final c = detectCombos([2, 3, 4, 4]);
      expect(c.hasStraight, isTrue);
      expect(c.straight!.low, equals(2));
      expect(c.straight!.high, equals(4));
      expect(c.pairs.length, equals(1)); // the two 4s
    });

    test('no combo on all-distinct non-consecutive values', () {
      final c = detectCombos([1, 3, 6]);
      expect(c.pairs, isEmpty);
      expect(c.hasTriple, isFalse);
      expect(c.hasStraight, isFalse);
    });

    test('same pool always yields identical combos (pure, no RNG)', () {
      final a = detectCombos([2, 2, 5, 6]);
      final b = detectCombos([2, 2, 5, 6]);
      expect(a.bonus, equals(b.bonus));
      expect(a.pairs.length, equals(b.pairs.length));
    });

    test('charge reroll re-detects combos (no stale combo_bonus)', () {
      // Regression: `reroll {die}` used to skip re-detection, so a broken
      // pair kept paying +1 on both dice and a new combo paid nothing.
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      while (sim.phase != 'player_turn') {
        final cmd = botCmd(sim);
        if (cmd == null || cmd['type'] == 'roll') break;
        sim.apply(cmd);
      }
      expect(sim.phase, equals('player_turn'));
      sim.apply({'type': 'roll'});
      // Force a known pool with a pair on dice 1+2, and grant one charge.
      sim.player['rolled'] = <int>[3, 3, 5];
      sim.player['rolled_max'] = <bool>[false, false, false];
      sim.player['combo_bonus'] = detectCombos([3, 3, 5]).bonus;
      sim.player['rerolls_left'] = 1;
      expect((sim.player['combo_bonus'] as List)[0], equals(1));
      sim.apply({'type': 'reroll', 'die': 1});
      final rolled = (sim.player['rolled'] as List).cast<int>();
      final expected = detectCombos(rolled).bonus;
      expect(sim.player['combo_bonus'], equals(expected),
          reason: 'combo_bonus must match the CURRENT pool after a charge '
              'reroll (pool now $rolled)');
    });
  });

  group('risky reroll (v4)', () {
    // Drive a bot run into the first player_turn with a fresh roll.
    Sim intoRolledTurn(int seed) {
      final sim = Sim(seed);
      while (true) {
        final cmd = botCmd(sim);
        if (cmd == null) fail('run ended before combat (seed $seed)');
        if (cmd['type'] == 'roll') {
          sim.apply(cmd);
          return sim;
        }
        sim.apply(cmd);
      }
    }

    test('max once per turn; consumes the seeded combat stream', () {
      final sim = intoRolledTurn(1);
      final ev1 = sim.apply({'type': 'reroll_risky', 'dice': [1]});
      expect(ev1.any((e) => e['type'] == 'risky_reroll'), isTrue);
      final ev2 = sim.apply({'type': 'reroll_risky', 'dice': [2]});
      expect(ev2.first['type'], equals('invalid_command'));
      expect(ev2.first['reason'], equals('risky_reroll_used'));
    });

    test('rejects assigned dice, bad indices, empty and duplicate subsets',
        () {
      final sim = intoRolledTurn(1);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'block'});
      expect(sim.apply({'type': 'reroll_risky', 'dice': [1]}).first['reason'],
          equals('die_already_assigned'));
      expect(sim.apply({'type': 'reroll_risky', 'dice': [99]}).first['reason'],
          equals('no_such_die'));
      expect(sim.apply({'type': 'reroll_risky', 'dice': []}).first['reason'],
          equals('no_dice_chosen'));
      expect(
          sim.apply({'type': 'reroll_risky', 'dice': [2, 2]}).first['reason'],
          equals('duplicate_die'));
    });

    test('replays are deterministic given the same commands', () {
      List<int> play(int seed) {
        final sim = intoRolledTurn(seed);
        sim.apply({'type': 'reroll_risky', 'dice': [1, 2]});
        return [(sim.player['rolled'] as List).cast<int>().fold(0, (a, b) => a + b),
                sim.eventHash];
      }
      expect(play(7), equals(play(7)));
    });
  });

  group('reward telegraphs (v4) — honest previews', () {
    test('every fight/elite node carries offers + preview from the offer '
        'stream; elites guarantee a tier-3 die', () {
      for (var seed = 1; seed <= 40; seed++) {
        final sim = Sim(seed);
        sim.apply({'type': 'start_run'});
        final nodes = (sim.map!['nodes'] as Map).cast<String, Map>();
        nodes.forEach((id, node) {
          final kind = node['kind'];
          if (kind != 'fight' && kind != 'elite') {
            expect(node['offers'], isNull, reason: 'seed $seed node $id');
            return;
          }
          final offers = (node['offers'] as List).cast<String>();
          expect(offers.length, inInclusiveRange(2, 3),
              reason: 'seed $seed node $id offer count');
          final preview = node['reward_preview'] as String;
          expect(offers.contains(preview), isTrue,
              reason: 'seed $seed node $id preview not among offers');
          if (kind == 'elite') {
            expect(offers.any((d) => dice[d]!.tier == 3), isTrue,
                reason: 'seed $seed elite $id lacks a rare die');
            expect(dice[preview]!.tier, equals(3),
                reason: 'seed $seed elite $id preview not rare');
          }
        });
      }
    });

    test('the reward actually offered matches the telegraphed offers', () {
      var checked = 0;
      for (var seed = 1; seed <= 20; seed++) {
        final sim = Sim(seed);
        while (true) {
          final cmd = botCmd(sim);
          if (cmd == null) break;
          final evs = sim.apply(cmd);
          for (final e in evs) {
            if (e['type'] == 'reward_offered') {
              final pos = sim.map!['position'];
              final node = (sim.map!['nodes'] as Map)['$pos'] as Map;
              final offers = (node['offers'] as List).cast<String>();
              expect(sim.offers, equals(offers),
                  reason: 'seed $seed node $pos telegraph mismatch');
              checked++;
            }
          }
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('starting boons (v4)', () {
    test('start_run without boons goes straight to map (back-compat)', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      expect(sim.phase, equals('map'));
      expect(sim.boons, isNull);
    });

    test('boons:true offers a deterministic 1-of-3 from the boon stream', () {
      final a = Sim(9);
      a.apply({'type': 'start_run', 'boons': true});
      expect(a.phase, equals('boon'));
      expect(a.boons!.length, equals(3));
      expect(a.boons!.toSet().length, equals(3)); // distinct
      for (final id in a.boons!) {
        expect(boons.containsKey(id), isTrue);
      }
      final b = Sim(9);
      b.apply({'type': 'start_run', 'boons': true});
      expect(b.boons, equals(a.boons)); // same seed => same offering
    });

    test('choose_boon applies effects and enters the map; 0 skips', () {
      final sim = Sim(9);
      sim.apply({'type': 'start_run', 'boons': true});
      final id = sim.boons![0];
      final diceBefore = (sim.player['dice'] as List).length;
      final goldBefore = sim.run!['gold'] as int;
      final evs = sim.apply({'type': 'choose_boon', 'index': 1});
      expect(evs.any((e) => e['type'] == 'boon_chosen'), isTrue);
      expect(sim.phase, equals('map'));
      final fx = boons[id]!.effects;
      if (fx.containsKey('gain_die')) {
        expect((sim.player['dice'] as List).length, equals(diceBefore + 1));
      }
      if (fx.containsKey('gold')) {
        expect(sim.run!['gold'], equals(goldBefore + (fx['gold'] as int)));
      }
      final skip = Sim(9);
      skip.apply({'type': 'start_run', 'boons': true});
      final evs2 = skip.apply({'type': 'choose_boon', 'index': 0});
      expect(evs2.any((e) => e['type'] == 'boon_skipped'), isTrue);
      expect(skip.phase, equals('map'));
    });
  });

  group('daily seed (v4)', () {
    test('pure: same date => same seed; different dates differ', () {
      expect(dailySeed(2026, 7, 24), equals(dailySeed(2026, 7, 24)));
      expect(dailySeed(2026, 7, 24), isNot(equals(dailySeed(2026, 7, 25))));
      expect(dailySeed(2026, 7, 24), isNot(equals(dailySeed(2027, 7, 24))));
    });

    test('seed is a valid LCG seed and drives identical runs', () {
      final s = dailySeed(2026, 12, 31);
      expect(s, greaterThan(0));
      expect(s, lessThan(2147483647));
      expect(playRun(s).sim.eventHash, equals(playRun(s).sim.eventHash));
    });
  });

  group('exact-kill / overkill / burn (v4) — observed in real runs', () {
    test('the new mechanics all fire across 60 bot runs', () {
      final seen = <String>{};
      for (var seed = 1; seed <= 60; seed++) {
        final sim = Sim(seed);
        while (true) {
          final cmd = botCmd(sim);
          if (cmd == null) break;
          for (final e in sim.apply(cmd)) {
            seen.add(e['type'] as String);
          }
        }
      }
      for (final t in [
        'combo_pair', 'combo_triple', 'combo_straight', 'burn_applied',
        'burn_tick', 'free_reroll_earned', 'risky_reroll', 'exact_kill',
        'overkill', 'splash_damage', 'boon_offered', 'boon_chosen',
      ]) {
        expect(seen.contains(t), isTrue, reason: 'event $t never observed');
      }
    });

    test('overkill surplus is capped and softens the next enemy', () {
      // Scan runs for an overkill followed by a splash_damage <= cap.
      for (var seed = 1; seed <= 60; seed++) {
        final sim = Sim(seed);
        int? pending;
        while (true) {
          final cmd = botCmd(sim);
          if (cmd == null) break;
          for (final e in sim.apply(cmd)) {
            if (e['type'] == 'overkill') {
              expect(e['surplus'] as int, inInclusiveRange(1, 5));
              pending = e['surplus'] as int;
            }
            if (e['type'] == 'splash_damage' && pending != null) {
              expect(e['amount'] as int, lessThanOrEqualTo(pending));
              expect(e['enemy_hp'] as int, greaterThanOrEqualTo(1));
              return; // proven once
            }
          }
        }
      }
      fail('no overkill->splash sequence observed in 60 runs');
    });
  });
  group('v0.3.1 balance pass (F7 early mercy + F8 ember floor)', () {
    test('early mercy: regular fights on layer <= 2 are softened', () {
      expect(earlyMercyAttackShave(2), equals(2));
      expect(earlyMercyAttackShave(3), equals(0));
      expect(earlyMercyAttackShave(4), equals(0));
      expect(earlyMercyHpCap(2), equals(28));
      // Find a seed whose first fight is soot_shade-class and verify the
      // spawned enemy is capped and shaved vs its roster definition.
      for (var seed = 1; seed <= 400; seed++) {
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
        sim.apply({'type': 'choose_node', 'node': fight});
        final enemy = sim.enemy!;
        final def = enemies[enemy['id']]!;
        // Layer-2 regulars: HP capped at 28, every intent amount shaved by 2
        // (min 1) relative to the roster definition.
        expect(enemy['max_hp'] as int, lessThanOrEqualTo(28),
            reason: 'seed $seed ${enemy['id']}');
        final pattern = (enemy['pattern'] as List).cast<Map>();
        for (var i = 0; i < def.pattern.length; i++) {
          final want = def.pattern[i].amount - 2;
          expect(pattern[i]['amount'], equals(want < 1 ? 1 : want),
              reason: 'seed $seed ${enemy['id']} intent $i');
        }
        return;
      }
      fail('no fight-adjacent start node found in 400 seeds');
    });

    test('elites and the boss never get the mercy shave', () {
      final sim = Sim(1);
      sim.apply({'type': 'start_run'});
      final events = <Map<String, Object?>>[];
      combatBegin(sim, 'pyre_howler', true, events, layer: 2);
      final def = enemies['pyre_howler']!;
      expect(sim.enemy!['max_hp'], equals(def.hp));
      expect((sim.enemy!['pattern'] as List).cast<Map>()[0]['amount'],
          equals(def.pattern[0].amount));
    });

    test('ember floor: every death banks at least 5 + layer reached', () {
      var checked = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final r = playRun(seed);
        if (r.sim.phase != 'run_lost') continue;
        checked++;
        final run = r.sim.run!;
        expect(run['embers'] as int, greaterThanOrEqualTo(5 + 2),
            reason: 'seed $seed banked ${run['embers']}');
      }
      expect(checked, greaterThan(0), reason: 'no losses in 60 seeds?');
    });
  });

  group('zombie-win fix (v0.3.2) — player death beats thorns/burn', () {
    // Drive a real run to its first fight, then force the razor's edge state
    // directly (the sim is a plain object; this is exactly the state a real
    // run can reach).
    Sim simInFight(int seed) {
      final sim = Sim(seed);
      sim.apply({'type': 'start_run'});
      while (sim.phase == 'map') {
        final map = sim.map!;
        final out =
            ((map['edges'] as Map)['${map['position']}'] as List).cast<int>();
        final fight = out.where((n) =>
            ((map['nodes'] as Map)['$n'] as Map)['kind'] == 'fight');
        sim.apply(
            {'type': 'choose_node', 'node': fight.isNotEmpty ? fight.first : out.first});
      }
      expect(sim.phase, equals('player_turn'),
          reason: 'seed $seed did not reach a fight directly');
      return sim;
    }

    test('lethal attack + same-tick burn kill = run lost, not reward', () {
      final sim = simInFight(42);
      sim.player['hp'] = 1;
      sim.player['block'] = 0;
      sim.enemy!['hp'] = 1;
      sim.enemy!['burn'] = 1;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 5};
      final events = sim.apply({'type': 'end_turn'});
      expect(events.any((e) => e['type'] == 'encounter_lost'), isTrue);
      expect(events.any((e) => e['type'] == 'encounter_won'), isFalse);
      expect(events.any((e) => e['type'] == 'burn_tick'), isFalse,
          reason: 'a dead delver has no burn tick');
      expect(sim.phase, equals('run_lost'));
    });

    test('lethal attack + same-tick thorns kill = run lost, not reward', () {
      final sim = simInFight(42);
      final thornsRelic = relicsOrderWithThorns();
      expect(thornsRelic, isNotNull, reason: 'no thorns relic in data');
      sim.run!['relics'] = <String>[thornsRelic!];
      sim.player['hp'] = 1;
      sim.player['block'] = 0;
      sim.enemy!['hp'] = 1;
      sim.enemy!['burn'] = 0;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 5};
      final events = sim.apply({'type': 'end_turn'});
      expect(events.any((e) => e['type'] == 'encounter_lost'), isTrue);
      expect(events.any((e) => e['type'] == 'encounter_won'), isFalse);
      expect(events.any((e) => e['type'] == 'thorns_dealt'), isFalse,
          reason: 'a dead delver deals no thorns');
      expect(sim.phase, equals('run_lost'));
    });

    test('non-lethal attack still lets burn finish the enemy (win intact)',
        () {
      final sim = simInFight(42);
      sim.player['hp'] = 10;
      sim.player['block'] = 0;
      sim.enemy!['hp'] = 1;
      sim.enemy!['burn'] = 1;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 5};
      final events = sim.apply({'type': 'end_turn'});
      expect(events.any((e) => e['type'] == 'burn_tick'), isTrue);
      expect(events.any((e) => e['type'] == 'encounter_won'), isTrue);
      expect(sim.phase, equals('reward'));
    });

    // Anchors the mechanic the boss death-insight coaches (bug-sweep-2): a
    // block intent protects the enemy during the FOLLOWING player turn, so
    // the honest advice is "attack before the guard is shown", never "hold
    // damage and strike after". If this timing ever changes, rewrite the
    // boss insight lines in data/insights.dart to match.
    test('enemy block from a block intent absorbs NEXT turn\'s attacks', () {
      final sim = simInFight(42);
      sim.player['hp'] = 30;
      sim.enemy!['hp'] = 50;
      sim.enemy!['max_hp'] = 50;
      sim.enemy!['intent'] = {'kind': 'block', 'amount': 10};
      // During the turn the block intent is SHOWN, the enemy has 0 block.
      expect(sim.enemy!['block'], equals(0));
      sim.apply({'type': 'end_turn'});
      // The enemy banked its block during its action...
      expect(sim.enemy!['block'], equals(10));
      // ...so this turn's attack is absorbed before hp is touched.
      sim.apply({'type': 'roll'});
      final hpBefore = sim.enemy!['hp'] as int;
      final events = sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
      final dmg = events.firstWhere((e) => e['type'] == 'damage_dealt');
      expect(dmg['blocked'], greaterThan(0));
      expect(
          (sim.enemy!['hp'] as int),
          equals(hpBefore -
              ((dmg['amount'] as int) - (dmg['blocked'] as int))));
    });
  });
}

/// First relic id whose hooks include thorns, or null if none exists.
String? relicsOrderWithThorns() {
  for (final id in relicsOrder) {
    if ((relics[id]!.hooks['thorns'] ?? 0) > 0) return id;
  }
  return null;
}
