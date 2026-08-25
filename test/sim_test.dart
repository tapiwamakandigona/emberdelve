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
// v0.5.0 re-anchor: the bestiary went 17 -> 30 enemies and the event deck
// 16 -> 28, which changes what the seeded spawn/offering streams draw. Content
// growth moves these hashes by design; resolution rules are untouched. Old v6
// value: 1842571558 (see progress.md for the v0.5.0 old -> new record).
//
// v7 re-anchor (2026-08-12): the keystone offering after the first won fight
// adds `keystone_offered` + `keystone_taken` to EVERY normal run and draws
// three cards from the `offer` stream, so every event hash moved by design.
// Rules for existing mechanics are untouched. Old v6 value: 2013675017; new
// value below, measured twice per seed and identical (tool/
// keystone_balance_probe.dart). Autoplay win rate 64.0% declining vs 66.0%
// taking over 200 seeds, so the fair-balance band is unaffected.
//
// v0.12.0 re-anchor (2026-08-16, "New Embers" content drop): the bestiary
// grew 30 -> 35 (4 regulars + 1 elite appended at their band ENDS) and the
// event deck 28 -> 31, so `_regularsFor/_elitesFor` pool lengths and the
// unseen-event pick change what every seeded spawn/offer stream draws.
// Content growth moves these hashes by design (v0.5.0 precedent); resolution
// rules are untouched and boss count stays 6, so the anchor seed still maps
// to the Ember Tyrant. Old v6 value: 1507173787. New values below measured
// twice per seed (identical) on local Flutter 3.44.9; old -> new for all six
// bosses recorded in progress.md.
//
// v0.22.0 re-anchor (2026-08-16, "The Crowned Deep" content drop): bosses
// 6 -> 8, which remaps `bossForSeed = seed % count` for EVERY seed — the
// re-anchor the enemies.dart ordering comment has warned about since v0.5.0,
// taken deliberately (docs/improvements/v0.22.0-crowned-deep-design.md). The
// anchor seed 20260723 ≡ 3 (mod 8) now draws the CINDER HIEROPHANT, not the
// Ember Tyrant; the pools also grew (enemies 35 -> 39, events 31 -> 33), so
// even same-boss runs re-hash. Old value: 1285794096. Measured twice per
// seed in-process AND across two separate processes
// (tool/golden_measure_probe_test.dart, tool/golden_boss_reach_probe_test.dart);
// old -> new for all bosses recorded in progress.md.
//
// v0.25.0 re-anchor (2026-08-16, "The Unquiet Deep" content drop): events
// 33 -> 39 and relics 28 -> 32 (all appended at END; content-as-data, zero
// logic). Deck growth changes the unseen-event pick and relic growth changes
// every gain_random_relic draw, so all seeded runs re-hash (v0.12.0/v0.22.0
// precedent). Boss mapping is untouched (still 8). Old value: 210389070.
// Reach re-proven for every anchor seed with
// tool/golden_boss_reach_probe_test.dart; old -> new in progress.md.
//
// v0.46.0 re-anchor (2026-08-25, "The Delvers Before" content drop): events
// 39 -> 45 and relics 32 -> 36 (appended at END; content-as-data, zero
// logic). Same cause as v0.25.0. Boss mapping untouched; every anchor seed
// still reaches its boss (re-proven, tool/reanchor_v0460_probe_test.dart).
// Old value: 1607954204.
const int goldenV6 = 2043266176;

// Boss anchors: one golden per boss, so a regression in ANY boss fight trips
// the gate. v0.5.0 took the roster from 3 to 6 bosses, which re-maps
// `seed % bossCount` and moved every one of these values. Old v0.4 values,
// for the record: Colossus 578589309 @ seed 20260725, Matriarch 1077392826
// @ seed 20260724.
//
// v0.22.0 (8 bosses): seeds congruent to 0..7 mod 8 hit each boss exactly
// once in boss-list order. The base run 20260720..20260727 was screened with
// tool/golden_boss_reach_probe_test.dart and four of those runs DIE BEFORE
// MEETING THEIR BOSS — a per-boss golden that never reaches its boss pins
// nothing about that boss fight. For those, the next seed in the same
// residue class (+8k) whose bot run provably emits the boss's
// `encounter_started` is used instead. Every seed below was verified to
// fight its boss; this is a stronger anchor scheme than the pre-v0.22.0
// consecutive-seed one, which never checked reach.
// v0.25.0 re-screen: the deck/roster growth changed which base seeds
// survive to their boss. 20260721 (ember_tyrant) now provably reaches its
// boss again, so the +8 substitute 20260729 is retired.
const Map<int, String> bossAnchorSeeds = {
  20260728: 'ashen_colossus', // 20260720 dies early (run_lost, no boss)
  20260721: 'ember_tyrant',
  20260722: 'pyre_matriarch',
  20260723: 'cinder_hierophant',
  20260724: 'the_bellows',
  20260725: 'ashfall_twins',
  20260734: 'slag_regent', // 20260726 dies early
  20260743: 'hearthless_king', // 20260727 and 20260735 die early
};

// v7 re-anchor (2026-08-12), old -> new, same cause as goldenV6 above:
//   ashen_colossus     1729684958 -> 201437516
//   ember_tyrant       2013675017 -> 1507173787
//   pyre_matriarch      537528265 -> 625118910
//   cinder_hierophant  1258842264 -> 1042046624
//   the_bellows        1746127677 -> 2005745586
//   ashfall_twins      1800621184 -> 642212611
//
// Second, NARROWER re-anchor (2026-08-12, player-HP floor): a killing blow used
// to publish a negative 'player_hp' in enemy_attacked, which the HUD printed
// verbatim ("-17") and TalkBack read aloud. HP is now floored at zero, so ONLY
// runs that end in a death change hash. Exactly one anchor seed loses:
//   ashfall_twins       642212611 -> 183009563   (run_lost, final hp 0)
// Measured twice per seed; the other five bosses and goldenV6 are unchanged,
// which is itself the evidence that the fix touched nothing but death.
//
// Per-boss goldens, pinned 2026-08-11 from measured builds, not guesses:
// identical values printed by CI runs 31447535252 and 31459628277 and by a
// local Flutter 3.44.9 run. (Historical: ember_tyrant equalled goldenV6 by
// construction while seed 20260723 drew it; since the v0.22.0 8-boss remap
// that construction belongs to cinder_hierophant — see the v0.22.0 block
// below.) If content is deliberately added to the spawn/event
// pools, re-anchor ALL of these from a real build and record old -> new in
// progress.md — never by editing a single one to green.
// v0.12.0 re-anchor (2026-08-16), old -> new, cause: bestiary 30 -> 35 and
// event deck 28 -> 31 (see goldenV6 note above):
//   ashen_colossus      201437516 -> 240246681
//   ember_tyrant       1507173787 -> 1285794096
//   pyre_matriarch      625118910 -> 1072189078
//   cinder_hierophant  1042046624 -> 1003403945
//   the_bellows        2005745586 -> 753684676
//   ashfall_twins       183009563 -> 1171602943
// v0.22.0 re-anchor (2026-08-16), old -> new (boss mapping AND anchor seeds
// changed together — see bossAnchorSeeds above; old seed in parentheses):
//   ashen_colossus     (20260722)  240246681 -> 1741421590 @ 20260728
//   ember_tyrant       (20260723) 1285794096 -> 1337987690 @ 20260729
//   pyre_matriarch     (20260724) 1072189078 ->  144677281 @ 20260722
//   cinder_hierophant  (20260725) 1003403945 ->  210389070 @ 20260723
//   the_bellows        (20260726)  753684676 -> 1476213392 @ 20260724
//   ashfall_twins      (20260727) 1171602943 -> 1206986981 @ 20260725
//   slag_regent        (new)                    789589633 @ 20260734
//   hearthless_king    (new)                    537232144 @ 20260743
// (hearthless_king was re-measured after its fairness tune, hp 100->98 and
// swing 34->32: 1087925192 -> 537232144; the other seven anchors were
// byte-identical across the tune, proving it touched only king fights.)
// cinder_hierophant equals goldenV6 by construction (same seed 20260723).
// v0.46.0 re-anchor (2026-08-25), old -> new, same anchor seeds:
//   ashen_colossus     1626301198 -> 2114249795
//   ember_tyrant       1459254341 -> 1274323147
//   pyre_matriarch      445696919 -> 1246566942
//   cinder_hierophant  1607954204 -> 2043266176
//   the_bellows         565723793 -> 1874083357
//   ashfall_twins      1991211581 -> 1238512999
//   slag_regent        1258221119 -> 2127043565
//   hearthless_king     510459434 -> 1841674163
const Map<String, int> bossGoldens = {
  'ashen_colossus': 2114249795,
  'ember_tyrant': 1274323147,
  'pyre_matriarch': 1246566942,
  'cinder_hierophant': 2043266176,
  'the_bellows': 1874083357,
  'ashfall_twins': 1238512999,
  'slag_regent': 2127043565,
  'hearthless_king': 1841674163,
};

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
        expect(
          resumed.eventHash,
          equals(plain.eventHash),
          reason: 'seed $seed event hash',
        );
        expect(
          resumed.stateHash(),
          equals(plain.stateHash()),
          reason: 'seed $seed state hash',
        );
      }
    });

    test('restore rejects a stale-version snapshot', () {
      final snap = Sim(1).snapshot();
      snap['version'] = 999;
      expect(() => Sim.restore(snap), throwsStateError);
    });

    test('golden determinism anchor (regression guard)', () {
      // Seed 20260723: mapped to the Ember Tyrant while the roster was 3 or
      // 6 bosses (20260723 ≡ 1 mod both); since v0.22.0's 8-boss roster it
      // maps to the Cinder Hierophant (≡ 3 mod 8) — a deliberate re-anchor,
      // see the goldenV6 comment. Boss choice remains a pure function of the
      // seed and consumes no RNG stream.
      final sim = playRun(20260723).sim;
      expect(sim.eventHash, equals(goldenV6));
    });

    test(
      'boss variety: every boss is reachable and its run is deterministic',
      () {
        // Mapping is pure arithmetic on the seed, so it is asserted exactly.
        bossAnchorSeeds.forEach((seed, boss) {
          expect(
            bossForSeed(seed),
            equals(boss),
            reason: 'seed $seed no longer maps to $boss',
          );
        });
        // Every boss must actually be reachable: no boss may be unreachable
        // because of a modulus accident.
        expect(
          bossAnchorSeeds.values.toSet().length,
          equals(bossAnchorSeeds.length),
        );
        // Each boss run must be reproducible run-to-run AND match its pinned
        // golden (bossGoldens above), so a drift in any single boss fight is
        // caught even when the shared v6 anchor happens to survive.
        bossAnchorSeeds.forEach((seed, boss) {
          final a = playRun(seed).sim.eventHash;
          final b = playRun(seed).sim.eventHash;
          expect(b, equals(a), reason: '$boss run is not reproducible');
          expect(
            a,
            equals(bossGoldens[boss]),
            reason: '$boss run drifted from its pinned golden',
          );
        });
      },
    );
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
        final edges = ((sim.map!['edges'] as Map)['$start'] as List)
            .cast<int>();
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
        expect(
          ['run_won', 'run_lost'].contains(r.sim.phase),
          isTrue,
          reason: 'seed $seed ended at ${r.sim.phase}',
        );
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
      expect(
        sim.player['combo_bonus'],
        equals(expected),
        reason:
            'combo_bonus must match the CURRENT pool after a charge '
            'reroll (pool now $rolled)',
      );
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
      final ev1 = sim.apply({
        'type': 'reroll_risky',
        'dice': [1],
      });
      expect(ev1.any((e) => e['type'] == 'risky_reroll'), isTrue);
      final ev2 = sim.apply({
        'type': 'reroll_risky',
        'dice': [2],
      });
      expect(ev2.first['type'], equals('invalid_command'));
      expect(ev2.first['reason'], equals('risky_reroll_used'));
    });

    test('rejects assigned dice, bad indices, empty and duplicate subsets', () {
      final sim = intoRolledTurn(1);
      sim.apply({'type': 'assign', 'die': 1, 'action': 'block'});
      expect(
        sim.apply({
          'type': 'reroll_risky',
          'dice': [1],
        }).first['reason'],
        equals('die_already_assigned'),
      );
      expect(
        sim.apply({
          'type': 'reroll_risky',
          'dice': [99],
        }).first['reason'],
        equals('no_such_die'),
      );
      expect(
        sim.apply({'type': 'reroll_risky', 'dice': []}).first['reason'],
        equals('no_dice_chosen'),
      );
      expect(
        sim.apply({
          'type': 'reroll_risky',
          'dice': [2, 2],
        }).first['reason'],
        equals('duplicate_die'),
      );
    });

    test('replays are deterministic given the same commands', () {
      List<int> play(int seed) {
        final sim = intoRolledTurn(seed);
        sim.apply({
          'type': 'reroll_risky',
          'dice': [1, 2],
        });
        return [
          (sim.player['rolled'] as List).cast<int>().fold(0, (a, b) => a + b),
          sim.eventHash,
        ];
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
          expect(
            offers.length,
            inInclusiveRange(2, 3),
            reason: 'seed $seed node $id offer count',
          );
          final preview = node['reward_preview'] as String;
          expect(
            offers.contains(preview),
            isTrue,
            reason: 'seed $seed node $id preview not among offers',
          );
          if (kind == 'elite') {
            expect(
              offers.any((d) => dice[d]!.tier == 3),
              isTrue,
              reason: 'seed $seed elite $id lacks a rare die',
            );
            expect(
              dice[preview]!.tier,
              equals(3),
              reason: 'seed $seed elite $id preview not rare',
            );
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
              expect(
                sim.offers,
                equals(offers),
                reason: 'seed $seed node $pos telegraph mismatch',
              );
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
        'combo_pair',
        'combo_triple',
        'combo_straight',
        'burn_applied',
        'burn_tick',
        'free_reroll_earned',
        'risky_reroll',
        'exact_kill',
        'overkill',
        'splash_damage',
        'boon_offered',
        'boon_chosen',
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
        final edges = ((sim.map!['edges'] as Map)['$start'] as List)
            .cast<int>();
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
        expect(
          enemy['max_hp'] as int,
          lessThanOrEqualTo(28),
          reason: 'seed $seed ${enemy['id']}',
        );
        final pattern = (enemy['pattern'] as List).cast<Map>();
        for (var i = 0; i < def.pattern.length; i++) {
          final want = def.pattern[i].amount - 2;
          expect(
            pattern[i]['amount'],
            equals(want < 1 ? 1 : want),
            reason: 'seed $seed ${enemy['id']} intent $i',
          );
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
      expect(
        (sim.enemy!['pattern'] as List).cast<Map>()[0]['amount'],
        equals(def.pattern[0].amount),
      );
    });

    test('ember floor: every death banks at least 5 + layer reached', () {
      var checked = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final r = playRun(seed);
        if (r.sim.phase != 'run_lost') continue;
        checked++;
        final run = r.sim.run!;
        expect(
          run['embers'] as int,
          greaterThanOrEqualTo(5 + 2),
          reason: 'seed $seed banked ${run['embers']}',
        );
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
        final out = ((map['edges'] as Map)['${map['position']}'] as List)
            .cast<int>();
        final fight = out.where(
          (n) => ((map['nodes'] as Map)['$n'] as Map)['kind'] == 'fight',
        );
        sim.apply({
          'type': 'choose_node',
          'node': fight.isNotEmpty ? fight.first : out.first,
        });
      }
      expect(
        sim.phase,
        equals('player_turn'),
        reason: 'seed $seed did not reach a fight directly',
      );
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
      expect(
        events.any((e) => e['type'] == 'burn_tick'),
        isFalse,
        reason: 'a dead delver has no burn tick',
      );
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
      expect(
        events.any((e) => e['type'] == 'thorns_dealt'),
        isFalse,
        reason: 'a dead delver deals no thorns',
      );
      expect(sim.phase, equals('run_lost'));
    });

    test('non-lethal attack still lets burn finish the enemy (win intact)', () {
      final sim = simInFight(42);
      sim.player['hp'] = 10;
      sim.player['block'] = 0;
      sim.enemy!['hp'] = 1;
      sim.enemy!['burn'] = 1;
      sim.enemy!['intent'] = {'kind': 'attack', 'amount': 5};
      final events = sim.apply({'type': 'end_turn'});
      expect(events.any((e) => e['type'] == 'burn_tick'), isTrue);
      expect(events.any((e) => e['type'] == 'encounter_won'), isTrue);
      // v7: a first won fight offers the run's keystone before its die
      // reward. The win is intact either way — declining lands on reward.
      expect(sim.phase, equals('keystone'));
      sim.apply({'type': 'choose_keystone', 'index': 0});
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
      final events = sim.apply({
        'type': 'assign',
        'die': 1,
        'action': 'attack',
      });
      final dmg = events.firstWhere((e) => e['type'] == 'damage_dealt');
      expect(dmg['blocked'], greaterThan(0));
      expect(
        (sim.enemy!['hp'] as int),
        equals(hpBefore - ((dmg['amount'] as int) - (dmg['blocked'] as int))),
      );
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
