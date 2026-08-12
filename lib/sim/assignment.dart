// sim/assignment.dart — one pure source of truth for assignment arithmetic.
//
// Both combat resolution and the UI's exact-value preview call this function.
// It must stay side-effect free: callers perform mutations and emit events
// only after an allowed result is returned.

import '../data/relics.dart';
import 'run_dice.dart';

class AssignmentResolution {
  final bool allowed;
  final int value;
  final String? invalidReason;
  final String? rune;
  final int runeBonus;

  /// Pending Echo charge consumed by this assignment: the die that armed it
  /// and the amount it pays. Zero/null when no charge applies.
  final int? echoFromDie;
  final int echoBonus;

  const AssignmentResolution._({
    required this.allowed,
    required this.value,
    this.invalidReason,
    this.rune,
    this.runeBonus = 0,
    this.echoFromDie,
    this.echoBonus = 0,
  });

  const AssignmentResolution.allowed(
    int value, {
    String? rune,
    int runeBonus = 0,
    int? echoFromDie,
    int echoBonus = 0,
  }) : this._(
         allowed: true,
         value: value,
         rune: rune,
         runeBonus: runeBonus,
         echoFromDie: echoFromDie,
         echoBonus: echoBonus,
       );

  const AssignmentResolution.invalid(String reason)
    : this._(allowed: false, value: -1, invalidReason: reason);
}

int _ownedRelicSum(Map? run, String hook) {
  final owned = (run?['relics'] as List?)?.cast<String>() ?? const <String>[];
  if (owned.isEmpty) return 0;
  var total = 0;
  // Catalog order is stable. Addition is commutative, but retaining the same
  // iteration rule as relic_hooks.dart keeps all aggregation deterministic.
  for (final id in relicsOrder) {
    if (owned.contains(id)) total += relics[id]!.hooks[hook] ?? 0;
  }
  return total;
}

/// Resolve exactly what assigning one rolled die would contribute.
///
/// [die] is one-based, matching the public command protocol. The caller
/// validates turn phase and roll/index presence before calling; this function
/// owns action compatibility and every additive assignment modifier.
AssignmentResolution resolveAssignment({
  required Map player,
  required Map enemy,
  required Map? run,
  required int die,
  required String action,
}) {
  if (action != 'attack' && action != 'block') {
    return const AssignmentResolution.invalid('unknown_action');
  }

  final resolvedDie = resolveRunDie(
    run,
    (player['dice'] as List).cast<String>()[die - 1],
  );
  final def = resolvedDie.def;
  final mods = def.mods;
  if (action == 'attack' && mods['block_only'] == true) {
    return const AssignmentResolution.invalid('die_is_block_only');
  }
  if (action == 'block' && mods['attack_only'] == true) {
    return const AssignmentResolution.invalid('die_is_attack_only');
  }

  final rolled = (player['rolled'] as List).cast<int>();
  final maxed = (player['rolled_max'] as List?)?.cast<bool>();
  final onMax = (maxed != null && maxed[die - 1])
      ? (mods['on_max_bonus'] as int? ?? 0)
      : 0;
  final combo = (player['combo_bonus'] as List?)?.cast<int>();

  var value = rolled[die - 1] + onMax + (combo != null ? combo[die - 1] : 0);
  if (action == 'attack') {
    value +=
        (mods['attack_bonus'] as int? ?? 0) +
        _ownedRelicSum(run, 'attack_flat');
    if (enemy['boss'] == true || enemy['elite'] == true) {
      value += _ownedRelicSum(run, 'elite_damage');
    }
  } else {
    value +=
        (mods['block_bonus'] as int? ?? 0) + _ownedRelicSum(run, 'block_flat');
  }
  final naturalFaces = (player['rolled_face'] as List?)?.cast<int>();
  final runeFaceMatches =
      resolvedDie.custom &&
      naturalFaces != null &&
      naturalFaces[die - 1] == resolvedDie.temperedFace;
  var runeBonus = 0;
  String? triggeredRune;
  if (runeFaceMatches) {
    final rune = resolvedDie.rune;
    if (rune == 'blade' && action == 'attack') {
      triggeredRune = rune;
      runeBonus = 2;
    } else if (rune == 'aegis' && action == 'block') {
      triggeredRune = rune;
      runeBonus = 2;
    } else if (rune == 'echo') {
      // Echo pays by arming the opposite verb, not by raising this value.
      triggeredRune = rune;
    }
  }
  value += runeBonus;

  // A pending Echo charge is the last additive term (contract §Arithmetic
  // order). It is armed by a previous assignment, so it can never pay the
  // assignment that armed it.
  final pending = player['echo_pending'];
  var echoBonus = 0;
  int? echoFromDie;
  if (pending is Map && pending['action'] == action) {
    echoBonus = pending['amount'] as int? ?? 0;
    echoFromDie = pending['die'] as int?;
    value += echoBonus;
  }

  return AssignmentResolution.allowed(
    value,
    rune: triggeredRune,
    runeBonus: runeBonus,
    echoFromDie: echoFromDie,
    echoBonus: echoBonus,
  );
}
