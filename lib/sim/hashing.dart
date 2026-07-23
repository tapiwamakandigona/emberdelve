// sim/hashing.dart — Deterministic hashing over sim values.
// SEALED SIM MODULE. 1:1 port of hash_value from legacy/defold/sim/init.lua
// (FROZEN — parity enforced by test/hash_parity_test.dart replaying the Lua
// golden event trace).
//
// Lua semantics preserved exactly:
//   * numbers: h = (h*31 + floor(v*8192) % MOD) % MOD
//   * strings: byte-wise djb2 (h*33 + byte); sim strings are ASCII only
//   * booleans: h*31 + (v ? 2 : 1)
//   * tables: keys stringified, sorted LEXICOGRAPHICALLY (so "10" < "2"),
//     then hash(keyString) followed by hash(value).
//   * Dart Lists stand in for Lua sequential arrays: they hash as maps with
//     1-based stringified keys ("1".."n"), lexicographically sorted.
//   * null values never occur inside hashed structures (Lua tables cannot
//     hold nil); callers substitute "none" for absent fields, as the Lua
//     state_hash does.

const int simHashMod = 2147483647;

int hashValue(int h, dynamic v) {
  if (v is bool) {
    // NOTE: check bool before num — order mirrors distinct Lua type() arms.
    return (h * 31 + (v ? 2 : 1)) % simHashMod;
  } else if (v is num) {
    return (h * 31 + ((v * 8192).floor() % simHashMod)) % simHashMod;
  } else if (v is String) {
    for (final b in v.codeUnits) {
      assert(b < 256, 'hashValue: non-ASCII/byte string');
      h = (h * 33 + b) % simHashMod;
    }
    return h;
  } else if (v is List) {
    final keys = List<String>.generate(v.length, (i) => '${i + 1}')..sort();
    for (final k in keys) {
      h = hashValue(h, k);
      h = hashValue(h, v[int.parse(k) - 1]);
    }
    return h;
  } else if (v is Map) {
    final byKey = <String, dynamic>{
      for (final e in v.entries) e.key.toString(): e.value,
    };
    final keys = byKey.keys.toList()..sort();
    for (final k in keys) {
      h = hashValue(h, k);
      h = hashValue(h, byKey[k]);
    }
    return h;
  } else if (v == null) {
    throw ArgumentError(
        'hashValue: null is unhashable (Lua tables cannot hold nil); '
        'substitute "none" for absent fields');
  }
  throw ArgumentError('hashValue: unsupported type ${v.runtimeType}');
}
