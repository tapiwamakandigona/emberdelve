// lib/game/run_trace.dart — spoiler-free floor trace for share text (v0.8.0).
// Pure Dart, no Flutter imports, fully testable.
//
// Studio lesson (docs/improvements/studio-priorities-2026-08-16.md §7):
// Wordle's share artifact works because it is instantly recognizable,
// states performance without spoiling the puzzle, and carries social
// capital. This is Emberdelve's version of that artifact: one colored
// square per floor, saying only "how it went" — never which nodes exist,
// what the map offers, or where the shops are. A shared-seed rival learns
// nothing about the delve except that someone survived (or didn't).
//
// Ethics line (§Ethics): the grid states facts. No streaks, no expiry, no
// taunts. The seed-challenge text states how to replay a seed and stops.
//
// The recorder OBSERVES sim events from the presentation side — exactly the
// recordCombatStats pattern. The sim itself is untouched: no snapshot keys,
// no golden movement, byte-identical save blobs for the sim's own map.

/// How one visited floor went. Order matters only chronologically.
const markClean = 'clean'; // floor survived with no player HP lost on it
const markHurt = 'hurt'; // floor survived but the delver bled for it

/// Accumulates one mark per floor entered, by watching the same event
/// stream the controller already forwards to its other observers.
class RunTrace {
  RunTrace();

  /// Chronological marks for every floor CLOSED so far (a floor closes when
  /// the next one is entered, or at the terminal event).
  final List<String> marks = [];

  /// 'won' | 'lost' | null while the run is still live.
  String? outcome;

  bool _open = false; // a floor bucket is currently accumulating
  bool _hurt = false;

  /// Feed one command's event batch. Safe to call with any events; only
  /// node_entered / enemy_attacked / hp_lost / run_won / run_lost matter.
  void observe(List<Map<String, Object?>> events) {
    for (final e in events) {
      switch (e['type']) {
        case 'node_entered':
          _close();
          _open = true;
          _hurt = false;
        case 'enemy_attacked':
        case 'counter_struck': // v0.47.0: a riposte hurts like any hit
          if (((e['damage'] as num?) ?? 0) > 0) _hurt = true;
        case 'hp_lost':
          _hurt = true;
        case 'run_won':
          _close();
          outcome = 'won';
        case 'run_lost':
          _close();
          outcome = 'lost';
      }
    }
  }

  void _close() {
    if (!_open) return;
    marks.add(_hurt ? markHurt : markClean);
    _open = false;
    _hurt = false;
  }

  bool get isEmpty => marks.isEmpty && !_open;

  /// Autosave side-channel (rides beside the sim snapshot like run_labels;
  /// Sim.restore ignores foreign keys). Captures the open bucket too, so a
  /// kill+resume mid-floor loses nothing.
  Map<String, Object?> toJson() => {
    'marks': List<String>.from(marks),
    if (outcome != null) 'outcome': outcome,
    if (_open) 'open': true,
    if (_open && _hurt) 'open_hurt': true,
  };

  static RunTrace fromJson(Object? raw) {
    final t = RunTrace();
    if (raw is! Map) return t;
    final m = raw['marks'];
    if (m is List) {
      for (final v in m) {
        if (v == markClean || v == markHurt) t.marks.add(v as String);
      }
    }
    final o = raw['outcome'];
    if (o == 'won' || o == 'lost') t.outcome = o as String;
    t._open = raw['open'] == true;
    t._hurt = raw['open_hurt'] == true;
    return t;
  }

  /// v0.57.0 The Fuller Record: the closed trace as one tiny string —
  /// 'c' per clean floor, 'h' per hurt floor ('' when empty). Run records
  /// bank this so a remembered Delver's Card can repaint its grid. The
  /// outcome is NOT encoded: the record's own `result` field already
  /// holds it, and stating a fact twice invites disagreement.
  String toCompact() => marks.map((m) => m == markHurt ? 'h' : 'c').join();

  /// Rebuild a CLOSED trace from [toCompact] output plus the outcome the
  /// record banked ('won' | 'lost' | null). Unknown characters are
  /// dropped, never guessed.
  static RunTrace fromCompact(String s, {String? outcome}) {
    final t = RunTrace();
    for (final ch in s.split('')) {
      if (ch == 'c') t.marks.add(markClean);
      if (ch == 'h') t.marks.add(markHurt);
    }
    if (outcome == 'won' || outcome == 'lost') t.outcome = outcome;
    return t;
  }
}

/// Render the finished trace as emoji rows, five floors per row:
///   🟩 floor survived untouched   🟨 floor survived, HP lost
///   🟥 the floor the delver fell on   🔥 the boss floor, Ember claimed
/// Returns '' for an empty trace (a run that ended before any floor —
/// nothing honest to show, so show nothing).
String traceGrid(RunTrace trace) {
  if (trace.marks.isEmpty) return '';
  final cells = <String>[
    for (final m in trace.marks) m == markHurt ? '🟨' : '🟩',
  ];
  if (trace.outcome == 'lost') {
    cells[cells.length - 1] = '🟥';
  } else if (trace.outcome == 'won') {
    cells[cells.length - 1] = '🔥';
  }
  final rows = <String>[];
  for (var i = 0; i < cells.length; i += 5) {
    rows.add(
      cells.sublist(i, i + 5 > cells.length ? cells.length : i + 5).join(),
    );
  }
  return rows.join('\n');
}

/// Screen-reader label for the visual grid — TalkBack must never be made to
/// read a row of emoji squares one by one. Counts, then the outcome.
String traceSemanticLabel(RunTrace trace) {
  if (trace.marks.isEmpty) return '';
  final clean = trace.marks.where((m) => m == markClean).length;
  final hurt = trace.marks.length - clean;
  final outcome = switch (trace.outcome) {
    'won' => 'the Ember claimed',
    'lost' => 'the delver fell',
    _ => 'still delving',
  };
  return 'Floor trace: ${trace.marks.length} floors, '
      '$clean unharmed, $hurt with blood spilt, $outcome.';
}

/// Copyable seed challenge for ANY finished run (the Balatro lesson: a seed
/// plus a claim is a complete invitation). States the replay path factually.
/// [grid] is the traceGrid output; blank grids are omitted.
String seedChallengeText({
  required int seed,
  required String difficulty,
  required int ascension,
  required bool won,
  required int floor,
  required int floors,
  String grid = '',
  String code = '',
}) {
  final diff = difficulty.toUpperCase() + (ascension > 0 ? ' A$ascension' : '');
  final line = won
      ? '🔥 Claimed the Ember — floor $floors of $floors'
      : '🕯️ Fell on floor $floor of $floors';
  // v0.37.0: when a Delve Code is available it replaces the bare seed — the
  // code packs delver + difficulty + ascension too, so the friend plays THIS
  // run, not one like it.
  final what = code.isEmpty ? 'seed $seed' : code;
  final claim = code.isEmpty
      ? 'Same seed, same delve'
      : 'Same code, same delve';
  return [
    'Emberdelve — $what ($diff)',
    if (grid.isNotEmpty) grid,
    line,
    '$claim: title screen → Delve a seed.',
  ].join('\n');
}
