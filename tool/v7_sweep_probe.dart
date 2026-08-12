// tool/v7_sweep_probe.dart — the v7 balance sweep and the command fuzz.
//
//   flutter test tool/v7_sweep_probe.dart --reporter expanded
//
// Two questions, one file:
//
//  1. SWEEP — does the Face Forge break the difficulty curve? Win rate is
//     measured across easy/normal/hard and the ascension ladder, with the new
//     powers off, keystone only, and keystone + temper. The curve must stay
//     monotonic (harder is harder) at every combination, or the gate the whole
//     hard/ascension economy rests on is a lie.
//
//  2. FUZZ — can any sequence of commands, valid or nonsense, break the sim?
//     Randomized command soup across seeds, checking hard invariants after
//     every single command.
//
// Results land in build/v7_sweep/metrics.json. This file asserts the
// invariants and monotonicity; the golden anchors live in test/sim_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/keystones.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

const _seeds = 120;

double _winRate(
  int seeds, {
  String difficulty = 'normal',
  int ascension = 0,
  bool keystones = true,
  bool tempers = false,
}) {
  var wins = 0;
  for (var s = 1; s <= seeds; s++) {
    final r = playRun(
      s * 7919,
      difficulty: difficulty,
      ascension: ascension,
      keystones: keystones,
      tempers: tempers,
    );
    if (r.sim.phase == 'run_won') wins++;
  }
  return wins / seeds;
}

/// Invariants that must hold after EVERY command, valid or rejected.
void _checkInvariants(Sim sim, String note) {
  final p = sim.player;
  expect(p['hp'], isA<int>(), reason: note);
  expect(p['hp'] as int, greaterThanOrEqualTo(0), reason: 'hp negative: $note');
  expect(
    p['hp'] as int,
    lessThanOrEqualTo(p['max_hp'] as int),
    reason: 'hp over max: $note',
  );
  expect(p['block'] as int, greaterThanOrEqualTo(0), reason: 'block <0: $note');

  final run = sim.run;
  if (run != null) {
    expect(run['gold'] as int, greaterThanOrEqualTo(0), reason: 'gold <0');
    final tempersUsed = run['tempers_used'] as int? ?? 0;
    expect(tempersUsed, lessThanOrEqualTo(1), reason: 'more than one temper');
    final ks = (run['keystones'] as List? ?? const []).cast<String>();
    expect(ks.length, lessThanOrEqualTo(keystoneCap), reason: 'keystone cap');
    expect(ks.toSet().length, ks.length, reason: 'duplicate keystone');
    for (final k in ks) {
      expect(keystones.containsKey(k), isTrue, reason: 'unknown keystone $k');
    }
    // Every pool entry must still resolve — the class of bug that crashed the
    // rest screen when tempered dice arrived.
    for (final id in (p['dice'] as List).cast<String>()) {
      final def = resolveRunDie(run, id).def;
      expect(def.size, greaterThan(0), reason: 'unresolvable die $id');
    }
    final custom = (run['custom_dice'] as Map? ?? const {});
    for (final entry in custom.entries) {
      final data = entry.value as Map;
      expect(
        faceRunes.contains(data['rune']),
        isTrue,
        reason: 'unknown rune on ${entry.key}',
      );
      expect(data['face'] as int, greaterThanOrEqualTo(1));
    }
  }

  // NOTE: enemy hp is legitimately negative once a killing blow lands — that
  // surplus IS the overkill splash carry — and runPost clears combatOver after
  // every command, leaving the corpse in state until the next combatBegin. So
  // the check only applies while a fight is genuinely still running.
  final enemy = sim.enemy;
  if (enemy != null && sim.phase == 'player_turn') {
    expect(enemy['hp'] as int, greaterThanOrEqualTo(0), reason: 'enemy hp <0');
  }
}

void main() {
  test(
    'sweep: the difficulty curve survives runes and keystones',
    () {
      final out = <String, Object?>{};
      for (final mode in const [
        ['off', false, false],
        ['keystone', true, false],
        ['keystone+temper', true, true],
      ]) {
        final label = mode[0] as String;
        final ks = mode[1] as bool;
        final tp = mode[2] as bool;

        final byDifficulty = <String, double>{};
        for (final d in const ['easy', 'normal', 'hard']) {
          byDifficulty[d] = _winRate(
            _seeds,
            difficulty: d,
            keystones: ks,
            tempers: tp,
          );
        }
        final byAscension = <String, double>{};
        for (final a in const [0, 3, 6, 12, 20]) {
          byAscension['$a'] = _winRate(
            _seeds,
            ascension: a,
            keystones: ks,
            tempers: tp,
          );
        }
        out[label] = {'difficulty': byDifficulty, 'ascension': byAscension};

        // Easy is never harder than normal, normal never harder than hard.
        expect(
          byDifficulty['easy']!,
          greaterThanOrEqualTo(byDifficulty['normal']!),
          reason: '$label: easy must not be harder than normal',
        );
        expect(
          byDifficulty['normal']!,
          greaterThanOrEqualTo(byDifficulty['hard']!),
          reason: '$label: normal must not be harder than hard',
        );
        // The ascension ladder must never rise as it climbs.
        final ladder = [
          '0',
          '3',
          '6',
          '12',
          '20',
        ].map((k) => byAscension[k]!).toList();
        for (var i = 1; i < ladder.length; i++) {
          expect(
            ladder[i],
            lessThanOrEqualTo(ladder[i - 1]),
            reason: '$label: ascension ${ladder[i]} rose at step $i',
          );
        }
        // ignore: avoid_print
        print('$label -> difficulty $byDifficulty  ascension $byAscension');
      }

      File('build/v7_sweep/metrics.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );

  test(
    'fuzz: no command soup can break a sim invariant',
    () {
      const runs = 60;
      const commandsPerRun = 400;
      var invalids = 0, applied = 0;
      final phaseHits = <String, int>{};

      for (var s = 0; s < runs; s++) {
        final rng = Random(s * 104729 + 17);
        var sim = Sim(s * 7919 + 3);
        sim.apply({'type': 'start_run'});

        for (var i = 0; i < commandsPerRun; i++) {
          // A terminal sim accepts NOTHING — there is no restart command, the
          // app builds a fresh Sim. An earlier version of this fuzz posted
          // start_run at run_lost and spent 80% of its budget being rejected by
          // a dead sim; it proved almost nothing. Fresh sim, keep exploring.
          if (sim.phase == 'run_won' || sim.phase == 'run_lost') {
            sim = Sim(s * 7919 + 3 + i);
            sim.apply({'type': 'start_run'});
          }
          phaseHits[sim.phase] = (phaseHits[sim.phase] ?? 0) + 1;

          // Mostly sensible play, so the fuzz reaches deep game states, with a
          // steady drip of nonsense aimed straight at the v7 commands.
          Map<String, Object?> cmd;
          if (rng.nextInt(100) < 65) {
            cmd = botCmd(sim, tempers: rng.nextBool()) ?? {'type': 'roll'};
          } else {
            cmd = switch (rng.nextInt(8)) {
              0 => {
                'type': 'temper_face',
                'die': rng.nextInt(8) - 2,
                'face': rng.nextInt(14) - 2,
                'rune': faceRunes.elementAt(rng.nextInt(faceRunes.length)),
              },
              1 => {
                'type': 'temper_face',
                'die': 1,
                'face': 1,
                'rune': 'not_a_rune',
              },
              2 => {'type': 'choose_keystone', 'index': rng.nextInt(6) - 1},
              3 => {
                'type': 'assign',
                'die': rng.nextInt(9) - 2,
                'action': 'echo',
              },
              4 => {'type': 'reroll', 'die': rng.nextInt(9) - 2},
              5 => {'type': 'end_turn'},
              6 => {'type': 'roll'},
              _ => {'type': 'not_a_command'},
            };
          }
          final evs = sim.apply(cmd);
          applied++;
          if (evs.any((e) => e['type'] == 'invalid_command')) invalids++;
          _checkInvariants(sim, 'seed $s cmd $i ${jsonEncode(cmd)}');
        }

        // A fuzzed sim must still round-trip: snapshot -> restore -> same state.
        final restored = Sim.restore(
          jsonDecode(jsonEncode(sim.snapshot())) as Map<String, dynamic>,
        );
        expect(
          restored.stateHash(),
          sim.stateHash(),
          reason: 'fuzzed state failed to round-trip at seed $s',
        );
      }

      // ignore: avoid_print
      print('fuzz: $applied commands, $invalids rejected, 0 invariant breaks');
      // ignore: avoid_print
      print('fuzz phases: $phaseHits');
      expect(invalids, greaterThan(0), reason: 'the nonsense must be rejected');
      // Coverage gate: a fuzz that never leaves one screen proves nothing.
      for (final phase in const [
        'map',
        'player_turn',
        'rest',
        'shop',
        'event',
        'reward',
        'keystone',
      ]) {
        expect(
          phaseHits[phase] ?? 0,
          greaterThan(20),
          reason: 'fuzz barely visited $phase — coverage has degraded',
        );
      }
      expect(
        invalids / applied,
        lessThan(0.6),
        reason: 'fuzz is mostly bouncing off a stuck sim, not exploring',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
