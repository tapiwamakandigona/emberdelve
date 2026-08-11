// data/mutators.dart — Weekly Delve run modifiers (P3). CONTENT AS DATA.
//
// A mutator is a single declared rule that reshapes a run. The Weekly Delve
// (game/weekly.dart) picks ONE mutator per 7-day window, deterministically
// from the weekly seed, and passes its id to start_run via cmd['mutators'].
//
// Ethics (spec §Ethics, same charter as the Daily Delve): the weekly is a
// shared-seed challenge, NOT a streak treadmill. A missed week is simply a
// missed week — nothing expires, nothing is punished. So these blurbs state
// a rule; none of them implies pressure.
//
// SEALED-SIM CONTRACT: the sim reads only the mutator *id* (a plain string).
// It never imports this file. This catalog exists for the UI (labels/blurbs)
// and for the deterministic weekly picker. Adding a mutator here does NOT
// wire it into the sim — the sim must learn the id explicitly (see
// sim/run_layer.dart and sim/combat.dart). Keep the two in lockstep.

class MutatorDef {
  final String id;
  final String name;
  final String blurb;
  const MutatorDef(this.id, this.name, this.blurb);
}

/// Deterministic authoring order — the weekly picker indexes into this, so a
/// reorder reshuffles which week gets which modifier. Append, don't reorder.
const List<String> mutatorsOrder = ['all_d4', 'elites_only', 'no_shops'];

const Map<String, MutatorDef> mutators = {
  'all_d4': MutatorDef(
    'all_d4',
    'Flint Week',
    'Every die rolls as a d4. Bigger dice keep their edges but lose their range — small, sharp, and mean.',
  ),
  'elites_only': MutatorDef(
    'elites_only',
    'Elite Gauntlet',
    'Every regular fight is an elite. Harder road, richer loot — every combat can drop a rare die.',
  ),
  'no_shops': MutatorDef(
    'no_shops',
    'No Quarter',
    'No shops on the map. What you find is all you get — no gold to spend your way out of trouble.',
  ),
};

MutatorDef mutatorDef(String id) {
  final def = mutators[id];
  if (def == null) throw ArgumentError('unknown mutator id: $id');
  return def;
}

/// True when [id] is a real mutator the sim knows how to apply. The sim keeps
/// its own switch, but the UI and picker validate through here first.
bool isKnownMutator(String id) => mutators.containsKey(id);
