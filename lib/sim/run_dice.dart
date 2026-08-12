// sim/run_dice.dart — catalog + run-local custom die resolution.
//
// The pool remains List<String>. Catalog IDs resolve directly; a `custom_N`
// entry resolves through run['custom_dice'] to its catalog base plus one
// tempered face/rune. Run-local data is JSON-safe and snapshot-owned by Sim.

import '../data/dice.dart';

const Set<String> faceRunes = {'blade', 'aegis', 'surge', 'echo'};

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
