// lib/game/controller.dart — presentation-side owner of the Sim.
// Holds the single sim + meta state, wraps every mutation in apply()+autosave,
// implements boot/resume (docs/m3-contract.md §9), and banks embers into the
// meta layer when a run ends. Screens read `sim.state()` and the events from
// `apply()`; nothing above the sim pokes its internals.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../audio/audio_service.dart';
import '../meta/meta.dart';
import '../sim/daily.dart';
import '../sim/sim.dart';

class GameController extends ChangeNotifier {
  Sim? sim;
  MetaState meta = MetaState();

  /// Wired by main(); null in tests, so gameplay never depends on audio.
  AudioService? audio;
  String? flash; // transient toast (invalid reasons, rewards, heals)
  bool _bankedThisRun = false;

  /// 'YYYY-MM-DD' while the current run is a Daily Delve; null otherwise.
  /// Presentation-only label (not persisted with the save — a resumed run
  /// simply loses the badge, never any state).
  String? dailyDate;

  /// Tests inject a temp directory here; production uses path_provider.
  final String? saveDirOverride;
  GameController({this.saveDirOverride});

  static const _saveFile = 'emberdelve_run.json';
  static const _terminal = {'idle', 'run_won', 'run_lost'};

  Future<File> _runFile() async {
    final dir =
        saveDirOverride ?? (await getApplicationSupportDirectory()).path;
    return File('$dir/$_saveFile');
  }

  /// Boot: load meta, then resume a saved run if one is mid-flight.
  Future<void> boot() async {
    meta = await MetaStore.load();
    try {
      final f = await _runFile();
      if (await f.exists()) {
        final snap = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (snap['version'] == simVersion &&
            !_terminal.contains(snap['phase'])) {
          sim = Sim.restore(snap);
          _bankedThisRun = false;
        } else {
          // Stale (older SIM_VERSION) or already-finished save: clear it so
          // the player lands on the title and starts fresh — no error wall.
          await f.delete();
        }
      }
    } catch (_) {
      // Corrupt or restore-rejected save => title screen, and drop the file
      // so the failure can't repeat on every boot.
      sim = null;
      await _clearSave();
    }
    notifyListeners();
    _syncAudio();
  }

  bool get _bossFight {
    final e = sim?.enemy;
    return e != null && (e['boss'] == true || e['elite'] == true);
  }

  void _syncAudio() => audio?.syncPhase(phase, bossFight: _bossFight);

  String? get phase => sim?.phase;
  Map<String, Object?>? get state => sim?.state();

  Future<void> _autosave() async {
    if (sim == null) return;
    try {
      final f = await _runFile();
      await f.writeAsString(jsonEncode(sim!.snapshot()));
    } catch (_) {}
  }

  void startRun(
      {String? character,
      int ascension = 0,
      bool boons = false,
      int? seed,
      String? daily}) {
    // Deterministic-enough seed for real play; runs are still fully replayable
    // from their seed. Daily runs pin [seed] via [startDailyRun].
    final s = seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    sim = Sim(s);
    _bankedThisRun = false;
    dailyDate = daily;
    apply({
      'type': 'start_run',
      if (character != null) 'character': character,
      'ascension': ascension,
      if (boons) 'boons': true,
    });
  }

  /// Daily Delve: everyone starts from the same seed for the device's local
  /// calendar date (same map, same offers, same boon offering). No streaks,
  /// no expiry — just a shared delve (spec §Ethics).
  void startDailyRun({String? character}) {
    final now = DateTime.now();
    final label = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    startRun(
        character: character,
        seed: dailySeed(now.year, now.month, now.day),
        boons: true,
        daily: label);
  }

  /// Fast restart from the death/victory ledger: a new run (fresh seed) with
  /// the same delver and ascension, straight into the boon pick.
  void delveAgain() {
    final run = sim?.run;
    startRun(
        character: run?['character'] as String?,
        ascension: run?['ascension'] as int? ?? 0,
        boons: true);
  }

  /// The ONLY mutation path. Applies, banks on terminal, autosaves, flashes.
  ///
  /// [terminalHold]: when the command ends the encounter (won or lost), delay
  /// the rebuild-notify by this long so the combat screen can finish its death
  /// choreography before the phase switches. State/saves update immediately;
  /// only the listener notification (and music change) is held.
  List<Map<String, Object?>> apply(Map<String, Object?> cmd,
      {Duration? terminalHold}) {
    if (sim == null) return const [];
    final events = sim!.apply(cmd);
    _handleFlash(events);
    if (_terminal.contains(sim!.phase)) _bankRun();
    _autosave();
    audio?.handleEvents(events);
    final ended = events.any((e) =>
        e['type'] == 'encounter_won' || e['type'] == 'encounter_lost');
    if (terminalHold != null && ended) {
      Future.delayed(terminalHold, () {
        notifyListeners();
        _syncAudio();
      });
    } else {
      notifyListeners();
      _syncAudio();
    }
    return events;
  }

  void _handleFlash(List<Map<String, Object?>> events) {
    flash = null;
    for (final e in events) {
      switch (e['type']) {
        case 'invalid_command':
          flash = _reason(e['reason'] as String?);
          break;
        case 'rested':
          flash = 'Rested — healed ${e['healed']} HP';
          break;
        case 'forged':
          flash = 'Forged into a stronger die';
          break;
        case 'relic_gained':
          flash = 'Relic acquired';
          break;
        case 'reward_skipped':
          flash = 'Reward skipped';
          break;
        case 'splash_damage':
          flash = 'Overkill splash — ${e['amount']} damage carried in';
          break;
      }
    }
  }

  String _reason(String? r) {
    switch (r) {
      case 'not_enough_gold':
        return 'Not enough gold';
      case 'already_sold':
        return 'Already sold';
      case 'no_rerolls_left':
        return 'No rerolls left';
      case 'pool_too_small':
        return 'Your pool is too small';
      case 'illegal_forge':
        return "That die can't be forged that way";
      case 'risky_reroll_used':
        return 'Risky reroll already spent this turn';
      case 'die_already_assigned':
        return "Assigned dice can't be rerolled";
      case 'no_dice_chosen':
        return 'Pick at least one die to reroll';
      case 'roll_first':
        return 'Roll before rerolling';
      default:
        return 'Not allowed';
    }
  }

  void _bankRun() {
    if (_bankedThisRun || sim == null) return;
    _bankedThisRun = true;
    final run = sim!.run;
    if (run == null) return;
    meta.embers += run['embers'] as int? ?? 0;
    meta.runsPlayed += 1;
    if (sim!.phase == 'run_won') {
      meta.runsWon += 1;
      final asc = run['ascension'] as int? ?? 0;
      if (asc >= meta.bestAscension) meta.bestAscension = asc + 1;
    }
    MetaStore.save(meta);
    _clearSave();
  }

  Future<void> _clearSave() async {
    try {
      final f = await _runFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// After a terminal screen, drop the sim so boot() -> title.
  void endToTitle() {
    sim = null;
    dailyDate = null;
    notifyListeners();
    _syncAudio();
  }

  bool unlock(String characterId) {
    final ok = meta.tryUnlock(characterId);
    if (ok) {
      MetaStore.save(meta);
      audio?.playSfx('unlock');
    }
    notifyListeners();
    return ok;
  }
}
