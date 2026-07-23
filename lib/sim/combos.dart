// sim/combos.dart — combo detection over the rolled dice pool (v4).
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Combos are a PURE DETERMINISTIC function of the rolled values — no RNG is
// consumed here, ever. The same pool always yields the same combos, so every
// near-miss the player feels ("5-5-4... so close to the triple") is real.
//
// Vocabulary (docs/m4-sim-contract.md §3):
//   pair     exactly two dice share a value  -> +1 per pair die (+2 total)
//   triple   three or more dice share a value -> ignite: 3 burn stacks
//   straight 3+ consecutive distinct values   -> free risky reroll next turn

/// Burn stacks applied by a triple ignite.
const int igniteBurnStacks = 3;

/// Additive bonus carried by EACH die of a pair (+2 across the pair).
const int pairBonusPerDie = 1;

class Pair {
  final int value;
  final List<int> dice; // 1-based indices, ascending
  const Pair(this.value, this.dice);
}

class Triple {
  final int value;
  final List<int> dice; // 1-based indices, ascending (3+)
  const Triple(this.value, this.dice);
}

class Straight {
  final int low;
  final int high;
  int get length => high - low + 1;
  const Straight(this.low, this.high);
}

class ComboResult {
  final List<int> bonus; // per-die additive bonus (same length as pool)
  final List<Pair> pairs; // ascending by value
  final List<Triple> triples; // ascending by value
  final Straight? straight; // longest straight of length >= 3, if any
  const ComboResult(this.bonus, this.pairs, this.triples, this.straight);

  bool get hasTriple => triples.isNotEmpty;
  bool get hasStraight => straight != null;
}

/// Detect all combos in [values] (the current rolled pool, in die order).
/// Deterministic: iteration in ascending face-value order; no RNG.
ComboResult detectCombos(List<int> values) {
  final byValue = <int, List<int>>{};
  for (var i = 0; i < values.length; i++) {
    byValue.putIfAbsent(values[i], () => <int>[]).add(i + 1);
  }
  final sortedValues = byValue.keys.toList()..sort();

  final bonus = List<int>.filled(values.length, 0);
  final pairs = <Pair>[];
  final triples = <Triple>[];
  for (final v in sortedValues) {
    final dice = byValue[v]!;
    if (dice.length == 2) {
      pairs.add(Pair(v, List<int>.from(dice)));
      for (final d in dice) {
        bonus[d - 1] += pairBonusPerDie;
      }
    } else if (dice.length >= 3) {
      triples.add(Triple(v, List<int>.from(dice)));
    }
  }

  // Longest run of consecutive distinct values, length >= 3. Ties broken by
  // the lowest starting value (first found while scanning ascending).
  Straight? straight;
  var runLo = -1, runHi = -1;
  for (final v in sortedValues) {
    if (runHi == v - 1) {
      runHi = v;
    } else {
      runLo = v;
      runHi = v;
    }
    final len = runHi - runLo + 1;
    if (len >= 3 && (straight == null || len > straight.length)) {
      straight = Straight(runLo, runHi);
    }
  }

  return ComboResult(bonus, pairs, triples, straight);
}
