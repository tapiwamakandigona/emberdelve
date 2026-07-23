// sim/hashing.dart — Deterministic hashing over event/state structures.
// SEALED SIM MODULE: pure Dart.
//
// Port of the Lua reference hasher (order-independent over keys, exact over
// values). Lua tables become Dart Maps/Lists; Lua's tostring(key) sort is
// emulated exactly:
//   * Map keys are hashed in lexicographic order of their string form.
//   * Lists are hashed like Lua array-tables: keys "1".."N" sorted
//     lexicographically ("1","10","2",...), each key string hashed, then the
//     element at that (1-based) index.
//   * null values are skipped entirely (a Lua table never holds nil).

const int hashMod = 2147483647;

int hashValue(int h, Object? v) {
  if (v == null) return h;
  if (v is bool) {
    // NOTE: bool before num — order matters in Dart type tests.
    h = (h * 31 + (v ? 2 : 1)) % hashMod;
  } else if (v is num) {
    h = (h * 31 + ((v * 8192).floor() % hashMod)) % hashMod;
  } else if (v is String) {
    for (final c in v.codeUnits) {
      h = (h * 33 + c) % hashMod;
    }
  } else if (v is List) {
    final keys = <String>[for (var i = 1; i <= v.length; i++) '$i']..sort();
    for (final k in keys) {
      h = hashValue(h, k);
      h = hashValue(h, v[int.parse(k) - 1]);
    }
  } else if (v is Map) {
    final entries = <String, Object?>{};
    v.forEach((key, value) {
      if (value != null) entries[key.toString()] = value;
    });
    final keys = entries.keys.toList()..sort();
    for (final k in keys) {
      h = hashValue(h, k);
      h = hashValue(h, entries[k]);
    }
  } else {
    throw ArgumentError('unhashable value type: ${v.runtimeType}');
  }
  return h;
}

/// Deep copy of plain JSON-like structures (maps, lists, scalars).
Object? deepCopy(Object? v) {
  if (v is Map) {
    final out = <String, Object?>{};
    v.forEach((k, val) => out[k.toString()] = deepCopy(val));
    return out;
  }
  if (v is List) return [for (final e in v) deepCopy(e)];
  return v;
}
