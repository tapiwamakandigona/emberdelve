// sim/rng.dart — Deterministic per-domain RNG streams.
// SEALED SIM MODULE: pure Dart, no dart:io, no dart:math Random.
//
// 1:1 port of legacy/defold/sim/rng.lua (FROZEN — bit-parity enforced by
// test/rng_parity_test.dart against Lua-generated vectors).
//
// Design:
//   * One run seed spawns independent named streams (map/combat/loot/shuffle)
//     so consuming one stream never shifts another.
//   * Park–Miller minstd LCG; every intermediate value stays below 2^53 so
//     results are bit-identical to the Lua implementation on every platform
//     (including dart2js / web, where ints are doubles).

const int _mod = 2147483647; // 2^31 - 1 (Mersenne prime)
const int _mul = 48271; // Park–Miller minstd multiplier

/// djb2-style string hash, arithmetic only, result in [0, _mod).
/// Matches Lua hash_string exactly (byte-wise over ASCII domain names).
int _hashString(String s) {
  var h = 5381;
  for (final b in s.codeUnits) {
    h = (h * 33 + b) % _mod;
  }
  return h;
}

class Rng {
  int seed;
  final String domain;
  int calls;

  Rng._(this.seed, this.domain, this.calls);

  /// Create a stream for [domain] derived from [runSeed].
  factory Rng(int runSeed, String domain) {
    var seed = (runSeed + _hashString(domain)) % _mod;
    if (seed < 0) seed += _mod; // Dart % is already non-negative; belt+braces
    if (seed == 0) seed = 1; // 0 is a fixed point of the LCG
    return Rng._(seed, domain, 0);
  }

  int nextRaw() {
    seed = (seed * _mul) % _mod;
    calls += 1;
    return seed;
  }

  /// Integer uniform in [lo, hi] inclusive.
  int range(int lo, int hi) {
    assert(hi >= lo, 'range: hi < lo');
    return lo + nextRaw() % (hi - lo + 1);
  }

  /// Roll one die with [sides] faces (1..sides).
  int die(int sides) => range(1, sides);

  /// Plain-map snapshot (JSON-safe; shape matches the Lua snapshot).
  Map<String, dynamic> snapshot() =>
      {'seed': seed, 'domain': domain, 'calls': calls};

  factory Rng.restore(Map<String, dynamic> snap) => Rng._(
      snap['seed'] as int, snap['domain'] as String, snap['calls'] as int);
}
