// lib/game/tips.dart — v0.10.0 "The First Delve": staged contextual tips.
//
// Replaces the up-front 4-card tutorial wall. Each tip fires at the moment
// of first contact with its concept, shows one card, once ever:
//
//   roll_spend  — first-ever fight starts (the only up-front card)
//   intent_fair — the enemy's first action resolves (the receipt moment:
//                 what just happened is exactly what the badge announced)
//   combos_pay  — first combo event (the pair just paid)
//   block_fades — first telegraphed attack ≥ [bigHitThreshold]
//
// Pure logic, no Flutter imports — unit-tested in test/tips_test.dart.
//
// Rules (design doc: docs/improvements/v0.10.0-first-delve-design.md):
//   • One tip at a time. A trigger firing while another tip is up is NOT
//     shown and NOT marked seen — every trigger recurs, so it surfaces at
//     the next first-contact moment. No queue, no wall.
//   • Dismissing marks the tip seen forever (persisted via MetaState).
//   • The manual how-to-play overlay suppresses tips while open (the
//     caller simply doesn't forward moments then).

/// Stable tip ids — persisted in MetaState.tipsSeen, never renamed.
class ContextTips {
  static const rollSpend = 'roll_spend';
  static const intentFair = 'intent_fair';
  static const combosPay = 'combos_pay';
  static const blockFades = 'block_fades';
  static const List<String> all = [rollSpend, intentFair, combosPay, blockFades];
}

/// An incoming telegraphed attack at or above this is a "big hit" — the
/// teachable moment for block. d6 max is 6; 4+ is worth blocking.
const int bigHitThreshold = 4;

class TipDirector {
  /// Shared with MetaState.tipsSeen — mutating here mutates the save state
  /// (the caller persists after [dismiss]).
  final Set<String> seen;

  /// The tip currently on screen, or null.
  String? active;

  TipDirector(this.seen);

  bool get allSeen => ContextTips.all.every(seen.contains);

  /// First-ever fight begins. Returns the tip to show, or null.
  String? onFightStart() => _fire(ContextTips.rollSpend);

  /// A batch of sim events was processed after a command.
  String? onEvents(List<Map<String, Object?>> events) {
    for (final e in events) {
      switch (e['type']) {
        case 'enemy_attacked':
        case 'enemy_blocked':
          final t = _fire(ContextTips.intentFair);
          if (t != null) return t;
          break;
        case 'combo_pair':
        case 'combo_triple':
        case 'combo_straight':
          final t = _fire(ContextTips.combosPay);
          if (t != null) return t;
          break;
      }
    }
    return null;
  }

  /// A turn began with this telegraphed enemy intent
  /// (`{'kind': 'attack'|'block'|'attack_block', 'amount': n, ...}`).
  String? onIntent(Map<String, Object?> intent) {
    final kind = intent['kind'];
    if (kind != 'attack' && kind != 'attack_block') return null;
    final amount = intent['amount'];
    if (amount is! int || amount < bigHitThreshold) return null;
    return _fire(ContextTips.blockFades);
  }

  /// The player dismissed the active tip — mark it seen forever.
  /// Returns true if this was the LAST unseen tip (caller may then set the
  /// legacy tutorialSeen flag so older builds never replay their wall).
  bool dismiss() {
    final a = active;
    if (a == null) return false;
    seen.add(a);
    active = null;
    return allSeen;
  }

  String? _fire(String id) {
    if (active != null || seen.contains(id)) return null;
    active = id;
    return id;
  }
}
