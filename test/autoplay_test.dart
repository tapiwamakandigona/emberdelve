// Port of legacy/defold/tests/autoplay.lua (seeded full-run autoplayer,
// M1 gate) PLUS the 100-seed outcome parity test against the Lua-generated
// test/fixtures/seed_outcomes.json (docs/flutter-port-contract.md §5).
//
// The greedy drive policy below is the `next_cmd` from
// tool/parity/gen_fixtures.lua — verbatim the same policy as
// tests/run_tests.lua drive() and autoplay.lua bot_cmd.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:test/test.dart';

const int kSeeds = 100;
const int kMaxCmds = 3000;
const int kBandLo = 20, kBandHi = 80; // percent
const int kSnapSeeds = 10; // seeds 1..N get the snapshot/restore twin check
const int kSnapAt = 25; // snapshot after this many applied commands

// ---------------------------------------------------------------------------
// Greedy policy: a pure function of sim.state() -> next command (or null at
// a terminal phase). Deterministic, so twin sims produce identical runs.
// Verbatim port of tool/parity/gen_fixtures.lua `next_cmd`.
// ---------------------------------------------------------------------------

Map<String, dynamic>? botCmd(Sim sim) {
  final st = sim.state();
  final phase = st['phase'] as String;
  if (phase == 'idle') {
    return {'type': 'start_run'};
  } else if (phase == 'map') {
    // First reachable node; prefer rest when hp < 50%, else prefer non-rest.
    final map = st['map'] as Map<String, dynamic>;
    final edges = (map['edges'] as Map)[map['position']] as List;
    final player = st['player'] as Map<String, dynamic>;
    final wantRest = (player['hp'] as int) * 2 < (player['max_hp'] as int);
    int? pick;
    for (var i = 0; i < edges.length; i++) {
      final kind = ((map['nodes'] as Map)[edges[i]] as Map)['kind'];
      if (wantRest && kind == 'rest') {
        pick = edges[i] as int;
        break;
      }
      if (!wantRest && kind != 'rest' && pick == null) pick = edges[i] as int;
    }
    return {'type': 'choose_node', 'node': pick ?? edges[0]};
  } else if (phase == 'player_turn') {
    final player = st['player'] as Map<String, dynamic>;
    final rolled = player['rolled'] as List?;
    if (rolled == null) return {'type': 'roll'};
    final assigned = player['assigned'] as Map;
    for (var i = 1; i <= rolled.length; i++) {
      if (!assigned.containsKey(i)) {
        // Attack unless block is still needed vs the SHOWN intent.
        final mods =
            diceData[(player['dice'] as List)[i - 1]]!['mods'] as Map;
        final intent = (st['enemy'] as Map)['intent'] as Map;
        var incoming = 0;
        if (intent['kind'] == 'attack' || intent['kind'] == 'attack_block') {
          incoming = intent['amount'] as int;
        }
        String action;
        if (incoming > (player['block'] as int) &&
            mods['attack_only'] != true) {
          action = 'block';
        } else if (mods['block_only'] != true) {
          action = 'attack';
        } else {
          action = 'block';
        }
        return {'type': 'assign', 'die': i, 'action': action};
      }
    }
    return {'type': 'end_turn'};
  } else if (phase == 'reward') {
    return {'type': 'choose_reward', 'index': 1}; // always take first offer
  } else if (phase == 'rest') {
    return {'type': 'rest'};
  }
  return null; // run_won / run_lost: terminal
}

/// Play one seed to terminal. Returns (sim, applied count, invalid count).
/// If [snapAt] is given, snapshot/restore there and continue on the restored
/// twin — proving mid-run persistence is lossless (autoplay.lua `play`).
(Sim, int, int) play(int seed, [int? snapAt]) {
  var sim = Sim(seed);
  var applied = 0, invalids = 0;
  while (applied < kMaxCmds) {
    final cmd = botCmd(sim);
    if (cmd == null) break;
    final evs = sim.apply(cmd);
    applied += 1;
    for (final ev in evs) {
      if (ev['type'] == 'invalid_command') invalids += 1;
    }
    if (snapAt != null && applied == snapAt) {
      sim = Sim.restore(sim.snapshot());
    }
  }
  return (sim, applied, invalids);
}

void main() {
  // Shared across both tests: play seeds 1..100 once.
  final results = <int, (Sim, int, int)>{};
  setUpAll(() {
    for (var seed = 1; seed <= kSeeds; seed++) {
      results[seed] = play(seed);
    }
  });

  test(
      'autoplay: seeds 1..$kSeeds all reach terminal, bot never illegal, '
      'win rate in $kBandLo%-$kBandHi% band', () {
    var wins = 0, losses = 0;
    for (var seed = 1; seed <= kSeeds; seed++) {
      final (sim, applied, invalids) = results[seed]!;
      expect(sim.phase == 'run_won' || sim.phase == 'run_lost', isTrue,
          reason: 'seed $seed not terminal after $applied commands '
              '(phase=${sim.phase})');
      expect(invalids, 0,
          reason: 'seed $seed: bot triggered $invalids invalid_command '
              'events');
      if (sim.phase == 'run_won') wins++;
      if (sim.phase == 'run_lost') losses++;
    }
    // ignore: avoid_print
    print('      wins=$wins losses=$losses (band $kBandLo%-$kBandHi%)');
    expect(wins >= kBandLo && wins <= kBandHi, isTrue,
        reason: 'win rate $wins% outside $kBandLo%-$kBandHi% balance band');
  });

  test(
      'autoplay: snapshot/restore twin check — seeds 1..$kSnapSeeds resume '
      'at command $kSnapAt with identical hashes', () {
    for (var seed = 1; seed <= kSnapSeeds; seed++) {
      final (plain, _, _) = results[seed]!;
      final (resumed, _, _) = play(seed, kSnapAt);
      expect(resumed.eventHash, plain.eventHash,
          reason: 'seed $seed: snapshot/restore diverged (event_hash)');
      expect(resumed.stateHash(), plain.stateHash(),
          reason: 'seed $seed: snapshot/restore diverged (state_hash)');
    }
  });

  test(
      'seed outcomes parity: seeds 1..$kSeeds reproduce Lua '
      'phase/event_hash/event_count (59 run_won / 41 run_lost)', () {
    final fx = jsonDecode(
            File('test/fixtures/seed_outcomes.json').readAsStringSync())
        as Map<String, dynamic>;
    final outcomes = (fx['outcomes'] as List).cast<Map<String, dynamic>>();
    expect(outcomes.length, kSeeds);
    var wins = 0, losses = 0;
    for (final want in outcomes) {
      final seed = want['seed'] as int;
      final (sim, _, _) = results[seed]!;
      expect(sim.phase, want['phase'],
          reason: 'seed $seed: phase diverged from Lua');
      expect(sim.eventHash, want['event_hash'],
          reason: 'seed $seed: event_hash diverged from Lua');
      expect(sim.eventCount, want['event_count'],
          reason: 'seed $seed: event_count diverged from Lua');
      if (want['phase'] == 'run_won') wins++;
      if (want['phase'] == 'run_lost') losses++;
    }
    expect(wins, 59, reason: 'fixture must anchor 59 wins');
    expect(losses, 41, reason: 'fixture must anchor 41 losses');
    // ignore: avoid_print
    print('      100-seed parity OK: $wins run_won / $losses run_lost');
  });
}
