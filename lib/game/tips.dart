// lib/game/tips.dart — v0.10.0 "The First Delve": staged contextual tips.
//
// Replaces the up-front 4-card tutorial wall. Each tip fires at the moment
// of first contact with its concept, shows one card, once ever:
//
//   whats_a_delve — the run map (the delve itself) first comes on screen
//                 (v0.30.0: review said the word was never explained)
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
  /// v0.30.0: our first outside review said "I still don't understand
  /// what's a delve". First contact with the delve is the run map itself,
  /// so the word is defined there, once, in one card.
  static const whatsADelve = 'whats_a_delve';
  static const rollSpend = 'roll_spend';
  static const intentFair = 'intent_fair';
  static const combosPay = 'combos_pay';
  static const blockFades = 'block_fades';

  /// v0.139.0 The Shown Anvil: the first rest fire with the anvil
  /// available — the temper system's only front door, previously
  /// explained nowhere before the sheet itself.
  static const firstAnvil = 'first_anvil';

  /// v0.153.0 The Shared Fire: the title screen after a first FINISHED
  /// run, before any daily — the shared delve's only front door. Gated on
  /// a first win until the retention lane (DEMAND 2026-08-31c): the
  /// players most at risk of not returning are the ones LOSING their
  /// opening runs, and they were never told tomorrow's shared delve
  /// exists. A finished run — won or lost — is the loop tasted.
  static const sharedDelve = 'shared_delve';

  /// v0.160.0 The Second Strike: the first rest fire where the player
  /// holds a tier-1 mark and the anvil is live — deepening's only front
  /// door (v0.155.0), previously explained nowhere before the sheet.
  static const deepMark = 'deep_mark';
  static const List<String> all = [
    whatsADelve,
    rollSpend,
    intentFair,
    combosPay,
    blockFades,
    firstAnvil,
    sharedDelve,
    deepMark,
  ];
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

  /// The run map — the delve itself — comes on screen. Returns the tip to
  /// show, or null. Fires once ever (v0.30.0: defines the word "delve" at
  /// the moment the player first stands inside one).
  String? onMapArrival() => _fire(ContextTips.whatsADelve);

  /// First-ever fight begins. Returns the tip to show, or null.
  String? onFightStart() => _fire(ContextTips.rollSpend);

  /// v0.139.0: the first rest fire where a temper is still available.
  /// The caller passes canTemper so a spent-anvil rest never teaches a
  /// button that is not on screen.
  /// v0.160.0: [hasShallowMark] — the pool holds a tier-1 marked die.
  /// The anvil card outranks the deepen card (a player who has never
  /// tempered cannot deepen), and the one-tip rule means the deepen card
  /// simply recurs at the next marked rest.
  String? onRestArrival({required bool canTemper, bool hasShallowMark = false}) {
    if (!canTemper) return null;
    final anvil = _fire(ContextTips.firstAnvil);
    if (anvil != null) return anvil;
    if (!seen.contains(ContextTips.firstAnvil)) return null;
    return hasShallowMark ? _fire(ContextTips.deepMark) : null;
  }

  /// v0.153.0: back on the title screen. The shared delve is taught only
  /// once the player has won a run (they know what a delve is and have
  /// tasted the loop) and only if they have never played a daily — a
  /// player who found the button alone never sees the card.
  String? onTitleArrival({
    required bool playedBefore,
    required bool dailyPlayed,
  }) => (playedBefore && !dailyPlayed) ? _fire(ContextTips.sharedDelve) : null;

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
  /// (`{'kind': 'attack'|'block'|'attack_block'|'charge'|'counter'|'stagger',
  /// 'amount': n, ...}`). A charge is a big telegraphed hit, so it counts
  /// toward the block-fades warning like any attack (v0.47.0).
  String? onIntent(Map<String, Object?> intent) {
    final kind = intent['kind'];
    if (kind != 'attack' && kind != 'attack_block' && kind != 'charge') {
      return null;
    }
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
