// sim/run_dice.dart — catalog + run-local custom die resolution.
//
// The pool remains List<String>. Catalog IDs resolve directly; a `custom_N`
// entry resolves through run['custom_dice'] to its catalog base plus one
// tempered face/rune. Run-local data is JSON-safe and snapshot-owned by Sim.

import '../data/dice.dart';

// v0.124.0: 'mend' joins the vocabulary. New runes append here AND in the
// temper sheet's offer list; the sim validates temper commands against
// this set (run_layer 'unknown_rune').
//
// v0.155.0 The Deep Mark: a mark carries a tier (1 or 2). The 'tier' key is
// OPTIONAL in the save shape — every pre-v0.155 custom die simply lacks it
// and resolves to tier 1, so old saves degrade to exactly their old meaning.
const Set<String> faceRunes = {
  'blade',
  'aegis',
  'surge',
  'echo',
  'mend',
  'gilt',
};

class RunDie {
  final String id;
  final String baseId;
  final DieDef def;
  final int? temperedFace;
  final String? rune;

  /// Mark depth: 1 for a plain mark, 2 for a deepened one. Always 1 on an
  /// untempered die.
  final int tier;

  const RunDie({
    required this.id,
    required this.baseId,
    required this.def,
    this.temperedFace,
    this.rune,
    this.tier = 1,
  });

  bool get custom => id != baseId;
}

RunDie resolveRunDie(Map? run, String id) {
  if (!id.startsWith('custom_')) {
    return RunDie(id: id, baseId: id, def: dieDef(id));
  }
  final custom = run?['custom_dice'];
  if (custom is! Map) throw StateError('missing custom die data: $id');
  final raw = custom[id];
  if (raw is! Map) throw StateError('missing custom die data: $id');
  final base = raw['base'];
  final face = raw['face'];
  final rune = raw['rune'];
  // v0.155.0: tier is optional (old saves have no key → tier 1); when
  // present it must be exactly 1 or 2 — anything else is corrupt data.
  final tier = raw['tier'] ?? 1;
  if (base is! String ||
      face is! int ||
      rune is! String ||
      !faceRunes.contains(rune) ||
      tier is! int ||
      tier < 1 ||
      tier > 2) {
    throw StateError('invalid custom die data: $id');
  }
  final def = dieDef(base);
  if (face < 1 || face > def.size) {
    throw StateError('custom die face out of bounds: $id');
  }
  return RunDie(
    id: id,
    baseId: base,
    def: def,
    temperedFace: face,
    rune: rune,
    tier: tier,
  );
}

/// Remove custom metadata once no pool entry references [id].
void removeOrphanCustomDie(Map? run, String id) {
  if (!id.startsWith('custom_')) return;
  final custom = run?['custom_dice'];
  if (custom is Map) custom.remove(id);
}

/// Display name for a rune id. Presentation-only; the sim never reads it.
String runeName(String? rune) => switch (rune) {
  'blade' => 'Blade',
  'aegis' => 'Aegis',
  'surge' => 'Surge',
  'echo' => 'Echo',
  'mend' => 'Mend',
  'gilt' => 'Gilt',
  _ => 'Rune',
};

/// One-line rule text for a rune, shown wherever a temper is offered or a
/// tempered die is inspected.
String runeBlurb(String rune) => switch (rune) {
  'blade' => 'On that face, attacks hit for +2.',
  'aegis' => 'On that face, blocks hold +2.',
  'surge' => 'On that face, you get a reroll back. Once per die each turn.',
  'echo' => 'On that face, your next opposite action gains +1.',
  'mend' => 'On that face, mend 1 HP. A full delver mends nothing.',
  'gilt' => 'On that face, the assignment pays 2 gold.',
  _ => '',
};

/// Display name carrying the mark's depth: 'Blade' at tier 1, 'Blade II'
/// when deepened. Presentation-only, like [runeName].
String runeTierName(String? rune, int tier) =>
    tier >= 2 ? '${runeName(rune)} II' : runeName(rune);

/// One-line rule text for a DEEPENED rune (tier 2), shown wherever a deep
/// mark is offered or inspected.
String runeDeepBlurb(String rune) => switch (rune) {
  'blade' => 'Deepened: attacks on that face hit for +3.',
  'aegis' => 'Deepened: blocks on that face hold +3.',
  'surge' => 'Deepened: the reroll returns twice per die each turn.',
  'echo' => 'Deepened: your next opposite action gains +2.',
  'mend' => 'Deepened: mend 2 HP. A full delver mends nothing.',
  'gilt' => 'Deepened: the assignment pays 3 gold.',
  _ => '',
};
