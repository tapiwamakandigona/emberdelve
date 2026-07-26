// lib/ui/screens/combat/hud.dart — part of screens.dart (see library header there).
// Combat HUD view-model (_Hud) + the assign-preview math.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

/// LFP-2a: what assigning [die] to [action] will resolve for, computed from
/// public sim state + content data (dieDef mods, combo_bonus, relic hooks) —
/// the same inputs sim/combat.dart reads. Returns -1 when the die can't take
/// the action (attack_only/block_only). PRESENTATION-ONLY twin of the sim's
/// assign math: test/feel_pregate_test.dart replays a scripted run and
/// asserts this against every die_assigned event the sim emits, so the two
/// cannot drift silently.
int assignPreview(
  Map player,
  Map enemy,
  List<String> relics,
  int die,
  String action,
) {
  final rolled = (player['rolled'] as List).cast<int>();
  final def = dieDef((player['dice'] as List).cast<String>()[die - 1]);
  final mods = def.mods;
  if (action == 'attack' && mods['block_only'] == true) return -1;
  if (action == 'block' && mods['attack_only'] == true) return -1;
  final maxed = (player['rolled_max'] as List?)?.cast<bool>();
  final onMax = (maxed != null && maxed[die - 1])
      ? (mods['on_max_bonus'] as int? ?? 0)
      : 0;
  final combo = (player['combo_bonus'] as List?)?.cast<int>();
  int hook(String h) {
    var t = 0;
    for (final id in relics) {
      t += relicDef(id).hooks[h] ?? 0;
    }
    return t;
  }

  var v = rolled[die - 1] + onMax + (combo != null ? combo[die - 1] : 0);
  if (action == 'attack') {
    v += (mods['attack_bonus'] as int? ?? 0) + hook('attack_flat');
    if (enemy['boss'] == true || enemy['elite'] == true) {
      v += hook('elite_damage');
    }
  } else {
    v += (mods['block_bonus'] as int? ?? 0) + hook('block_flat');
  }
  return v;
}

/// Immutable snapshot of everything the combat HUD reads, derived per scoped
/// section from live sim state (see `_CombatScreenState._hud`).
class _Hud {
  final Map st;
  final Map enemy;
  final Map player;
  final Map intent;
  final int turn;
  final List<int>? rolled;
  final Map assigned;
  final List<bool>? maxed;
  final List<String> dice0;
  final int rerolls;
  final bool riskyUsed;
  final bool freeReroll;
  final int enemyHp;
  final bool compact;
  final double maxHudScale;
  final double chipScale;
  final double trayViewH;
  final bool trayScrolls;
  final int hiddenDice;

  const _Hud({
    required this.st,
    required this.enemy,
    required this.player,
    required this.intent,
    required this.turn,
    required this.rolled,
    required this.assigned,
    required this.maxed,
    required this.dice0,
    required this.rerolls,
    required this.riskyUsed,
    required this.freeReroll,
    required this.enemyHp,
    required this.compact,
    required this.maxHudScale,
    required this.chipScale,
    required this.trayViewH,
    required this.trayScrolls,
    required this.hiddenDice,
  });
}
