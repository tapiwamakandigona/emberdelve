// sim/rng.dart — Deterministic per-domain RNG streams.
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Direct port of the proven Lua implementation (see repo history: sim/rng.lua,
// golden-verified cross-VM). Park–Miller minstd LCG; every intermediate value
// stays far below 2^53, so behavior is identical to the Lua 5.4 / LuaJIT
// reference and safe even on VMs that box ints as doubles.

const int rngMod = 2147483647; // 2^31 - 1 (Mersenne prime)
const int rngMul = 48271; // Park–Miller minstd multiplier

// djb2-style string hash, arithmetic only, result in [0, rngMod).
int hashDomainString(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = (h * 33 + c) % rngMod;
  }
  return h;
}

class Rng {
  int seed;
  final String domain;
  int calls;

  Rng._(this.seed, this.domain, this.calls);

  /// Create a stream for [domain] derived from [runSeed].
  factory Rng.create(int runSeed, String domain) {
    var seed = (runSeed + hashDomainString(domain)) % rngMod;
    if (seed < 0) seed += rngMod;
    if (seed == 0) seed = 1; // 0 is a fixed point of the LCG
    return Rng._(seed, domain, 0);
  }

  int nextRaw() {
    seed = (seed * rngMul) % rngMod;
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

  /// Plain-map snapshot (JSON-safe, for save/restore).
  Map<String, Object> snapshot() =>
      {'seed': seed, 'domain': domain, 'calls': calls};

  factory Rng.restore(Map<String, dynamic> snap) => Rng._(
      snap['seed'] as int, snap['domain'] as String, snap['calls'] as int);
}
