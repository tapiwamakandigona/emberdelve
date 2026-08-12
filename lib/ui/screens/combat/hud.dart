// lib/ui/screens/combat/hud.dart — part of screens.dart (see library header there).
// Combat HUD view-model (_Hud) + the assign-preview math.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

/// LFP-2a: what assigning [die] to [action] will resolve for, computed from
/// public sim state. Returns -1 when the die can't take the action
/// (attack_only/block_only). This is a thin UI adapter over the sim's pure
/// assignment resolver, not a second copy of the arithmetic.
int assignPreview(Map player, Map enemy, Map? run, int die, String action) {
  final resolved = resolveAssignment(
    player: player,
    enemy: enemy,
    run: run,
    die: die,
    action: action,
  );
  return resolved.allowed ? resolved.value : -1;
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
