// lib/meta/forge.dart — the Ember Forge gate (spec R8, v0.4.0; revised v0.6.0).
//
// ONE one-time purchase ("Ember Forge") unlocks the endgame:
//   - the Ascension ladder (rungs above 0)
// Everything else stays free forever: full runs on easy/normal/HARD, every
// delver (ember-priced, as designed), the Daily and Weekly Delve, themes, the
// ledger. No ads, no consumables, no timers — the gate must pass the spec
// §Ethics test: "would the player endorse it if we explained exactly how it
// works?" Explanation we stand behind: the complete game is free; the endgame
// ladder is the supporter's tier that funds future acts.
//
// v0.6.0: HARD moved to the free tier (retention doc 2026-08-11 §5 business
// question). Hard is the natural week-two content; gating it cost more
// players than it converted. The ladder alone remains the supporter's tier.
// A profile whose sticky preference was clamped off hard pre-0.6.0 keeps its
// stored 'normal' — moving it back silently would be a surprise switch.
//
// All gating happens OUTSIDE the sealed sim — these helpers only shape the
// start_run params the player may choose, never the resolution of a run.
import 'meta.dart';

/// Play Console product id of the one-time Ember Forge unlock.
const String forgeProductId = 'ember_forge_unlock';

/// Difficulties selectable without the Forge (v0.6.0: hard is free).
const Set<String> freeDifficulties = {'easy', 'normal', 'hard'};

/// May [m] start a run at difficulty [id]?
bool canSelectDifficulty(MetaState m, String id) =>
    m.forgeUnlocked || freeDifficulties.contains(id);

/// The highest ascension rung [m] may start a run at right now.
/// Free profiles delve at rung 0; Forge owners climb as far as they've earned
/// (the ladder itself is still earned one win at a time — never bought).
int maxAscensionFor(MetaState m) =>
    m.forgeUnlocked ? m.bestAscension.clamp(0, 20) : 0;

/// Clamp a requested (difficulty, ascension) pair to what [m] is entitled to.
/// Defense-in-depth for every startRun path: UI locks are the polite layer,
/// this is the guarantee.
({String difficulty, int ascension}) clampRunParams(
  MetaState m, {
  required String difficulty,
  required int ascension,
}) =>
    (
      difficulty: canSelectDifficulty(m, difficulty) ? difficulty : 'normal',
      ascension: ascension.clamp(0, maxAscensionFor(m)),
    );
