// game/difficulty.dart — Easy / Medium / Hard (owner-directed 2026-07-25).
// Pure Dart. Difficulty scales enemy BEHAVIOUR (speed, reaction windows,
// detection) plus one heart of slack on Easy — never cheap stat walls:
// enemy HP and contact damage are identical on every difficulty, so combat
// mastery transfers between modes and Hard stays fair.

enum Difficulty { easy, medium, hard }

class DifficultyMods {
  /// Multiplies enemy movement / charge / dive speeds.
  final double speed;

  /// Multiplies telegraph wind-ups and attack cooldowns (higher = easier:
  /// more reaction time, less frequent attacks).
  final double telegraph;

  /// Multiplies detection / aggro ranges.
  final double aggro;

  /// Extra player max hearts (Easy's one heart of slack).
  final int bonusHearts;

  const DifficultyMods({
    required this.speed,
    required this.telegraph,
    required this.aggro,
    required this.bonusHearts,
  });

  static const easy = DifficultyMods(
      speed: 0.85, telegraph: 1.35, aggro: 0.8, bonusHearts: 1);
  static const medium =
      DifficultyMods(speed: 1.0, telegraph: 1.0, aggro: 1.0, bonusHearts: 0);
  static const hard = DifficultyMods(
      speed: 1.2, telegraph: 0.7, aggro: 1.25, bonusHearts: 0);

  static DifficultyMods of(Difficulty d) => switch (d) {
        Difficulty.easy => easy,
        Difficulty.medium => medium,
        Difficulty.hard => hard,
      };
}

/// Parse the persisted id; unknown/legacy values fall back to medium.
Difficulty difficultyFromId(String id) => switch (id) {
      'easy' => Difficulty.easy,
      'hard' => Difficulty.hard,
      _ => Difficulty.medium,
    };

String difficultyId(Difficulty d) => switch (d) {
      Difficulty.easy => 'easy',
      Difficulty.medium => 'medium',
      Difficulty.hard => 'hard',
    };
