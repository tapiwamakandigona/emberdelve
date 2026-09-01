// lib/game/hearths.dart — THE SEVEN HEARTHS (v0.178.0, retention lane).
//
// The first seven DISTINCT local days a delve is finished each light one
// hearth on the title screen; the seventh settles [hearthGrantEmbers]
// embers and the row retires. §Ethics charter, strictly: the days need
// not be consecutive, nothing ever goes out, nothing expires, and the
// copy states facts — no countdowns, no owing, no loss-framing.
//
// State lives in MetaState (hearthDaysLit / lastHearthDay /
// sevenHearthsSettled), lit from GameController's run-end paths.

const int hearthCount = 7;
const int hearthGrantEmbers = 60;

/// The title line under the hearth row, for [lit] hearths (0..7).
/// Present tense, facts only. The unlit copy says the hearths keep —
/// the anti-streak promise is explicit, not implied.
String hearthLine(int lit) => switch (lit.clamp(0, hearthCount)) {
  0 => 'Seven hearths wait — one lights for each day you delve. '
      'They keep: no hearth ever goes out.',
  1 => 'First hearth lit. Any day you delve lights the next.',
  2 => 'Second hearth lit. Five wait, and they keep.',
  3 => 'Third hearth lit. Past halfway by the next.',
  4 => 'Fourth hearth lit. Three wait, and they keep.',
  5 => 'Fifth hearth lit. Two wait.',
  6 => 'Sixth hearth lit. The seventh settles $hearthGrantEmbers embers.',
  _ => 'Seven hearths burn. $hearthGrantEmbers embers settled '
      'into your pouch.',
};
