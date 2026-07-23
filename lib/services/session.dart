// GameSession — the single owner of the running Sim on the UI side.
//
// Responsibilities (docs/m1-contract.md §9, adapted to Flutter):
//   * every sim.apply(cmd) goes through [apply], which autosaves
//     jsonEncode(sim.snapshot()) under [saveKey] whenever >=1 event came back;
//   * [loadSaved] restores a non-terminal snapshot on boot (Sim.restore
//     normalizes jsonDecode's stringified keys — verified by
//     test/midrun_restore_test.dart);
//   * screens render ONLY from [state] + [lastEvents]; sim internals stay
//     sealed behind this class.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sim/sim.dart';

const String saveKey = 'run';

/// Terminal phases — a save in one of these routes to Title, not resume.
bool isTerminalPhase(String? phase) => phase == 'run_won' || phase == 'run_lost';

class GameSession extends ChangeNotifier {
  Sim? _sim;

  /// Events returned by the most recent [apply]; screens use them for
  /// transient feedback (damage pops, log lines). Never mutated by widgets.
  List<Map<String, dynamic>> lastEvents = const [];

  bool get hasRun => _sim != null;

  String get phase => _sim == null ? 'idle' : _sim!.phase;

  /// Read-only view of sim state (live references — treat as immutable).
  Map<String, dynamic> get state => _sim!.state();

  /// Restore a saved, non-terminal run if one exists. Returns true when a
  /// run was resumed (caller routes straight to the phase's screen).
  Future<bool> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(saveKey);
    if (raw == null) return false;
    try {
      final snap = jsonDecode(raw) as Map<String, dynamic>;
      if (isTerminalPhase(snap['phase'] as String?)) return false;
      _sim = Sim.restore(snap);
      lastEvents = const [];
      notifyListeners();
      return true;
    } catch (_) {
      // Corrupt/incompatible save: drop it rather than crash the boot.
      await prefs.remove(saveKey);
      return false;
    }
  }

  /// Start a fresh run. The UI layer may use the clock for seeding — the sim
  /// itself stays fully deterministic from the seed.
  Future<void> newRun({int? seed}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(saveKey);
    _sim = Sim(seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff);
    await apply({'type': 'start_run'});
  }

  /// Apply a command, autosave when it produced events, notify listeners.
  Future<List<Map<String, dynamic>>> apply(Map<String, dynamic> cmd) async {
    final sim = _sim;
    if (sim == null) return const [];
    final events = sim.apply(cmd);
    if (events.isNotEmpty) {
      lastEvents = events;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(saveKey, jsonEncode(sim.snapshot()));
      notifyListeners();
    }
    return events;
  }

  /// Back to title (run stays saved unless terminal).
  Future<void> toTitle() async {
    if (isTerminalPhase(phase)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(saveKey);
    }
    _sim = null;
    lastEvents = const [];
    notifyListeners();
  }

  /// Whether a resumable (non-terminal) save exists — drives "Continue".
  static Future<bool> hasResumableSave() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(saveKey);
    if (raw == null) return false;
    try {
      final snap = jsonDecode(raw) as Map<String, dynamic>;
      return !isTerminalPhase(snap['phase'] as String?);
    } catch (_) {
      return false;
    }
  }
}
