// Reproducible gameplay-depth research, not player telemetry or a balance gate.
// dart run tool/depth_review_probe.dart
// Counts current executable catalogs and samples the existing greedy bot.
// No Flutter, persistence, private information or source changes.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/data/boons.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/keystones.dart';
import 'package:emberdelve/sim/run_dice.dart';

num _median(List<int> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

void main() {
  final intentKinds = <String, int>{};
  var simple = 0;
  for (final enemy in enemies.values) {
    final kinds = enemy.pattern.map((i) => i.kind).toSet();
    for (final kind in kinds) {
      intentKinds.update(kind, (n) => n + 1, ifAbsent: () => 1);
    }
    if (kinds.every(
      (kind) => const {'attack', 'block', 'attack_block'}.contains(kind),
    )) {
      simple++;
    }
  }
  final samples = <Map<String, Object?>>[];
  for (final character in ['kindler', 'warden', 'gambler', 'runesmith']) {
    for (final difficulty in ['easy', 'normal', 'hard']) {
      var wins = 0, invalids = 0, capped = 0, turns = 0;
      final sizes = <int>[];
      final lossFloors = <int>[];
      final hashes = <Map<String, int>>[];
      for (var seed = 1; seed <= 50; seed++) {
        final run = playRun(
          seed,
          character: character,
          difficulty: difficulty,
          tempers: true,
        );
        wins += run.sim.phase == 'run_won' ? 1 : 0;
        invalids += run.invalids;
        if (!const {'run_won', 'run_lost'}.contains(run.sim.phase)) capped++;
        turns += run.sim.turnsTotal;
        sizes.add((run.sim.player['dice'] as List).length);
        if (run.sim.phase == 'run_lost') {
          final map = run.sim.map!;
          lossFloors.add(
            ((map['nodes'] as Map)['${map['position']}'] as Map)['layer']
                as int,
          );
        }
        hashes.add({
          'seed': seed,
          'state': run.sim.stateHash(),
          'event': run.sim.eventHash,
        });
      }
      lossFloors.sort();
      sizes.sort();
      samples.add({
        'character': character,
        'difficulty': difficulty,
        'seeds': '1..50',
        'runs': 50,
        'wins': wins,
        'win_percent': wins * 2,
        'mean_combat_turns': turns / 50,
        'median_final_pool': _median(sizes),
        'median_loss_floor': lossFloors.isEmpty ? null : _median(lossFloors),
        'invalid_commands': invalids,
        'nonterminal_runs': capped,
        'hashes': hashes,
      });
      if (invalids != 0 || capped != 0) {
        throw StateError(
          'Probe failed: $character/$difficulty invalid=$invalids capped=$capped',
        );
      }
    }
  }
  final report = {
    'method':
        'Current greedy bot, 4 characters x 3 difficulties x seeds 1..50; boons, keystones and tempers enabled. Not representative of human skill, retention or fairness.',
    'parameters': {
      'ascension': 0,
      'boons': true,
      'keystones': true,
      'tempers': true,
      'mutators': <String>[],
      'command_cap_per_run': 4000,
      'total_runs': 600,
    },
    'catalog': {
      'characters': characters.length,
      'dice': dice.length,
      'enemies': enemies.length,
      'bosses': enemies.values.where((e) => e.boss).length,
      'elites': enemies.values.where((e) => e.elite).length,
      'relics': relics.length,
      'events': events.length,
      'boons': boons.length,
      'mutators': mutators.length,
      'keystones': keystones.length,
      'runes': faceRunes.length,
      'enemies_only_attack_block_combinations': simple,
      'enemy_intent_kind_presence': intentKinds,
    },
    'samples': samples,
  };
  final file = File('build/art_depth_review/depth-report.json')
    ..createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(
    jsonEncode({
      'catalog': report['catalog'],
      'samples': samples.map((s) => Map.of(s)..remove('hashes')).toList(),
    }),
  );
}
