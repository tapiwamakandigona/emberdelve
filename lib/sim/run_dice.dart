// sim/run_dice.dart — catalog + run-local custom die resolution.
//
// The pool remains List<String>. Catalog IDs resolve directly; a `custom_N`
// entry resolves through run['custom_dice'] to its catalog base plus one
// tempered face/rune. Run-local data is JSON-safe and snapshot-owned by Sim.

import '../data/dice.dart';

// v0.124.0: 'mend' joins the vocabulary. New runes append here AND in the
// temper sheet's offer list; the sim validates temper commands against
// this set (run_layer 'unknown_rune').
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

  const RunDie({
    required this.id,
    required this.baseId,
    required this.def,
    this.temperedFace,
    this.rune,
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
  if (base is! String ||
      face is! int ||
      rune is! String ||
      !faceRunes.contains(rune)) {
    throw StateError('invalid custom die data: $id');
  }
  final def = dieDef(base);
  if (face < 1 || face > def.size) {
    throw StateError('custom die face out of bounds: $id');
  }
  return RunDie(id: id, baseId: base, def: def, temperedFace: face, rune: rune);
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
