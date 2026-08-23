// lib/game/tour.dart — v0.8.0 "The Guided Delve": anchored onboarding tour.
//
// Pure logic, no Flutter imports — unit-tested in test/tour_test.dart, same
// contract style as tips.dart. The UI layer (tour_overlay.dart) renders a
// spotlight over the anchor widget for [active] and forwards player moments
// here; this class only decides WHICH beat is on screen and WHEN the tour
// is over.
//
// Design doc: docs/improvements/onboarding-anchored-tour-2026-08-23.md
//
// Rules:
//   • Beats run strictly in order; exactly one is active at a time.
//   • Action beats (roll / pick / spend) complete ONLY when the player
//     performs the real action — never by tapping the card.
//   • Info beats (intent / reroll) complete on tap-to-continue.
//   • SKIP is always available and ends the whole tour immediately.
//   • Completion or skip stamps MetaState.tourSeenVersion = tourVersion —
//     the caller persists. Anyone with a lower stamp sees the tour once,
//     INCLUDING veterans of the old card wall (that is the point).
//   • While a beat is on screen the TipDirector must be suppressed (the
//     caller simply doesn't forward moments to it, mirroring the manual
//     how-to-play rule in tips.dart).

/// Bump when the tour changes enough that everyone should see it again.
const int tourVersion = 2;

/// Stable beat ids — order here IS the play order. Never renamed.
class TourBeats {
  static const roll = 'tour_roll'; // anchor: dice tray → "Tap ROLL."
  static const pick = 'tour_pick'; // anchor: a rolled die → "Tap a die."
  static const spend = 'tour_spend'; // anchor: ATTACK/BLOCK zone
  static const intent = 'tour_intent'; // anchor: enemy intent badge (info)
  static const reroll = 'tour_reroll'; // anchor: reroll affordance (info)
  static const List<String> all = [roll, pick, spend, intent, reroll];

  /// Info beats advance on tap; action beats advance on the real action.
  static const Set<String> infoBeats = {intent, reroll};
}

/// The player moments the combat screen forwards. One enum, so the UI
/// can't invent stringly-typed moments the director never heard of.
enum TourMoment { rolled, diePicked, actionSpent }

class TourDirector {
  /// Settings → "How to play (guided tour)" sets this; the next combat
  /// build consumes it (SettingsScreen has no controller reference — this
  /// one static flag is the whole bridge, cleared on consume).
  static bool replayRequested = false;

  /// Version stamp already persisted for this profile (MetaState field).
  final int seenVersion;

  TourDirector({required this.seenVersion, bool replay = false})
    : _running = replay || seenVersion < tourVersion,
      _index = 0;

  bool _running;
  int _index;

  /// Whether the tour wants the overlay on screen at all.
  bool get running => _running && _index < TourBeats.all.length;

  /// The beat currently on screen, or null when the tour is idle/done.
  String? get active => running ? TourBeats.all[_index] : null;

  /// True when [active] advances on tap rather than on a player action.
  bool get activeIsInfo =>
      active != null && TourBeats.infoBeats.contains(active);

  /// 0-based progress for the overlay's "2 of 5" label.
  int get step => _index;
  int get total => TourBeats.all.length;

  /// The real action happened. Advances only if it matches the active
  /// action beat; stray moments (e.g. rolling again during an info beat)
  /// are ignored so the tour can never soft-lock. Returns true when the
  /// tour just finished (caller stamps + persists).
  bool onMoment(TourMoment m) {
    if (!running || activeIsInfo) return false;
    final match = switch (active) {
      TourBeats.roll => m == TourMoment.rolled,
      TourBeats.pick => m == TourMoment.diePicked,
      TourBeats.spend => m == TourMoment.actionSpent,
      _ => false,
    };
    if (!match) return false;
    _index++;
    return _finishIfDone();
  }

  /// Tap-to-continue on an info beat. No-op on action beats — those only
  /// move on the real action. Returns true when the tour just finished.
  bool advanceInfo() {
    if (!running || !activeIsInfo) return false;
    _index++;
    return _finishIfDone();
  }

  /// SKIP: ends the tour now. Always allowed (§Ethics). Returns true —
  /// the caller stamps tourSeenVersion exactly as on completion, so a
  /// skipped tour never nags again.
  bool skip() {
    _running = false;
    _index = TourBeats.all.length;
    return true;
  }

  bool _finishIfDone() {
    if (_index >= TourBeats.all.length) {
      _running = false;
      return true;
    }
    return false;
  }
}
