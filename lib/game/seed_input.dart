// lib/game/seed_input.dart — custom-seed entry (v0.3.4, review note #5).
// Pure function, no Flutter imports. The sim is fully seed-deterministic, so
// "play a friend's seed" only needs a stable text → seed mapping.
import '../sim/rng.dart';

/// Map free-form input to a valid run seed in [1, 2^31-2].
///
/// - Digit strings replay that exact seed (the number shown on the summary),
///   so copy → paste round-trips.
/// - Any other text hashes deterministically (same word → same delve on
///   every device), namespaced so words can't collide with daily seeds.
/// - Blank input returns null (caller keeps the random-seed path).
int? parseSeedInput(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  const mod = 0x7fffffff; // 2^31 - 1 (seed must stay below the LCG modulus)
  var seed = int.tryParse(s) != null
      ? int.parse(s) % mod
      : hashDomainString('emberdelve-custom:$s');
  if (seed < 0) seed += mod;
  if (seed == 0) seed = 1; // 0 is a fixed point of the LCG
  return seed;
}
