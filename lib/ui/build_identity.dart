// lib/ui/build_identity.dart — presentation-only identity for the run's pool.
//
// This deliberately derives from existing DieDef data rather than adding a
// sim field. The same ordered pool always produces the same identity; no RNG,
// save migration or replay/golden change is involved.
import 'package:flutter/material.dart';

import '../data/dice.dart';
import '../sim/run_dice.dart';

enum BuildPath { ember, blade, aegis, heart }

@immutable
class RunBuildIdentity {
  final BuildPath path;
  final int dominantSize;
  final int dominantTier;
  final int specialDice;
  final Map<int, int> sizeCounts;

  const RunBuildIdentity({
    required this.path,
    required this.dominantSize,
    required this.dominantTier,
    required this.specialDice,
    required this.sizeCounts,
  });

  String get name => switch (path) {
    BuildPath.ember => 'Emberbound',
    BuildPath.blade => 'Bladeforged',
    BuildPath.aegis => 'Aegisforged',
    BuildPath.heart => 'Heartforged',
  };

  String get description => switch (path) {
    BuildPath.ember => 'A mixed pool built to answer different turns.',
    BuildPath.blade => 'Attack-focused dice turn openings into pressure.',
    BuildPath.aegis => 'Guard-focused dice buy time against heavy intent.',
    BuildPath.heart =>
      'Steady dice raise the floor; surge dice reward high rolls.',
  };

  IconData get icon => switch (path) {
    BuildPath.ember => Icons.local_fire_department,
    BuildPath.blade => Icons.flash_on,
    BuildPath.aegis => Icons.shield,
    BuildPath.heart => Icons.auto_awesome,
  };

  Color get color => switch (path) {
    BuildPath.ember => const Color(0xFFF08A2C),
    BuildPath.blade => const Color(0xFFE14B4B),
    BuildPath.aegis => const Color(0xFF72A7E8),
    BuildPath.heart => const Color(0xFFE8C24A),
  };

  int countFor(int sides) => sizeCounts[sides] ?? 0;
}

/// [run] is the run ledger, needed to resolve v7 run-local `custom_N` ids. A
/// tempered die counts as its catalog base: the rune changes what a face pays,
/// never what kind of die it is.
RunBuildIdentity buildIdentity(Iterable<String> dieIds, {Map? run}) {
  final scores = <BuildPath, int>{for (final path in BuildPath.values) path: 0};
  final sizeCounts = <int, int>{};
  var special = 0;
  var dominantSize = 4;
  var dominantTier = 1;

  for (final id in dieIds) {
    DieDef? def;
    if (id.startsWith('custom_')) {
      try {
        def = resolveRunDie(run, id).def;
      } catch (_) {
        def = null; // custom data missing (corrupt save): skip, never crash
      }
    } else {
      def = dice[id];
    }
    if (def == null) continue; // forward-compatible corrupt/unknown save
    final mods = def.mods;
    sizeCounts[def.size] = (sizeCounts[def.size] ?? 0) + 1;
    if (def.size > dominantSize) dominantSize = def.size;
    if (def.tier > dominantTier) dominantTier = def.tier;
    if (mods.isEmpty) {
      scores[BuildPath.ember] = scores[BuildPath.ember]! + 1;
      continue;
    }
    special++;
    if (mods['attack_only'] == true) {
      scores[BuildPath.blade] = scores[BuildPath.blade]! + 3;
    }
    if (mods['block_only'] == true) {
      scores[BuildPath.aegis] = scores[BuildPath.aegis]! + 3;
    }
    scores[BuildPath.blade] =
        scores[BuildPath.blade]! + (mods['attack_bonus'] as int? ?? 0);
    scores[BuildPath.aegis] =
        scores[BuildPath.aegis]! + (mods['block_bonus'] as int? ?? 0);
    scores[BuildPath.heart] =
        scores[BuildPath.heart]! +
        (mods['on_max_bonus'] as int? ?? 0) +
        (mods.containsKey('min_value') ? 1 : 0);
  }

  // Iteration order is the deliberate stable tie-break:
  // Ember -> Blade -> Aegis -> Heart.
  var path = BuildPath.ember;
  var best = scores[path]!;
  for (final candidate in BuildPath.values.skip(1)) {
    final score = scores[candidate]!;
    if (score > best) {
      path = candidate;
      best = score;
    }
  }
  return RunBuildIdentity(
    path: path,
    dominantSize: dominantSize,
    dominantTier: dominantTier,
    specialDice: special,
    sizeCounts: Map.unmodifiable(sizeCounts),
  );
}
