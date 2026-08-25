// game/obituary.dart — The Obituary (v0.51.0): a run's story told back in
// two or three honest sentences on the summary screen.
//
// Design doc: docs/improvements/v0.51.0-delve-obituary-design.md.
// Honesty contract (docs/spec.md §Ethics): every figure comes from the
// finished run; losses are dignified, never mocking; no streak language,
// no invitation to spend. Deterministic: template choice is keyed on the
// run seed, so the same run always tells the same story — tests pin the
// exact strings.

/// The epitaph paragraph for a finished run. Pure and sim-free: callers
/// gather the facts (controller.delveStoryText does this live; tests feed
/// them directly). [killerName] matters only for losses and may be '' for
/// legacy records — the story then ends the run without inventing a killer.
/// [cleanFloors] counts floors survived without losing a drop of HP
/// (RunTrace markClean). [epithetTitle] is '' when no epithet is worn.
String obituaryText({
  required bool won,
  required String delverName,
  required String epithetTitle,
  required String difficulty,
  required int ascension,
  required int floor,
  required int floors,
  required int cleanFloors,
  required String killerName,
  required String bossName,
  required int embers,
  required bool short,
  required int seed,
}) {
  final who = epithetTitle.isEmpty ? delverName : '$delverName, $epithetTitle';
  final diff = difficulty.isEmpty
      ? 'Normal'
      : difficulty[0].toUpperCase() + difficulty.substring(1);
  final asc = ascension > 0 ? ' (Ascension $ascension)' : '';
  final road = short ? ' by the Shorter Road' : '';
  final clean = cleanFloors <= 0
      ? ''
      : cleanFloors == 1
      ? ', one of them without a scratch'
      : ', $cleanFloors of them without a scratch';
  final emberWord = embers == 1 ? 'ember' : 'embers';
  if (won) {
    final opener = seed.isEven
        ? '$who came back up.'
        : '$who walked out with the Ember.';
    final felled = bossName.isEmpty ? '' : ' $bossName felled at the bottom.';
    return '$opener All $floors floors on $diff$asc$road$clean.'
        '$felled $embers $emberWord banked.';
  }
  final opener = seed.isEven ? 'Here fell $who.' : 'The delve took $who.';
  final ended = killerName.isEmpty
      ? 'there the delve ended'
      : 'there $killerName ended the run';
  return '$opener Floor $floor of $floors on $diff$asc$road$clean — '
      '$ended. $embers $emberWord carried home.';
}

/// The card-sized cut of the same story (v0.54.0 The Epitaph): one or two
/// short sentences for the Delver's Card image. It restates NOTHING the
/// card already shows (mode, embers, trace grid) — only the narrative the
/// numbers can't carry: how it ended, and who ended it. Same contracts as
/// [obituaryText]: pure, deterministic on [seed], losses dignified, every
/// name a banked fact. Tests pin the exact strings.
String epitaphLine({
  required bool won,
  required String delverName,
  required String epithetTitle,
  required int floor,
  required String killerName,
  required String bossName,
  required int seed,
}) {
  final who = epithetTitle.isEmpty ? delverName : '$delverName, $epithetTitle';
  if (won) {
    final opener = seed.isEven
        ? '$who came back up.'
        : '$who walked out with the Ember.';
    return bossName.isEmpty
        ? opener
        : '$opener $bossName felled at the bottom.';
  }
  final opener = seed.isEven ? 'Here fell $who' : 'The delve took $who';
  return killerName.isEmpty
      ? '$opener on floor $floor.'
      : '$opener — $killerName ended the run on floor $floor.';
}
