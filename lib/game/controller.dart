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
import '../data/characters.dart';
import '../data/dice.dart';
import '../data/relics.dart';
import '../meta/meta.dart';
import '../sim/daily.dart';
import '../sim/sim.dart';
import 'daily_share.dart';

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
    // First-run on-ramp (v0.3.3): steer a brand-new profile toward easy by
    // moving the VISIBLE selector — what's highlighted is what they get, so
    // there is never a silent difficulty switch. One tap ends the steering.
    if (meta.steerToEasy) meta.preferredDifficulty = 'easy';
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

  /// Seed of the current run (null when no run is live). Presentation-side
  /// identity key — e.g. the map screen uses it to reset cross-run UI state.
  int? get runSeed => sim?.runSeed;

  /// Serialized, atomic autosave: the snapshot is captured synchronously (so
  /// it matches the state the command produced, even if `sim` moves on or is
  /// dropped before the write lands), writes are chained on a queue (so two
  /// rapid commands can't interleave bytes in one file), and each save goes
  /// to a temp file first and is renamed into place (so a crash mid-write
  /// can never leave a truncated save — boot would silently discard it).
  Future<void> _saveQueue = Future.value();
  Future<void> _autosave() {
    if (sim == null) return Future.value();
    final snap = jsonEncode(sim!.snapshot());
    _saveQueue = _saveQueue.then((_) async {
      try {
        final f = await _runFile();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(snap, flush: true);
        await tmp.rename(f.path);
      } catch (_) {}
    });
    return _saveQueue;
  }

  void startRun(
      {String? character,
      int ascension = 0,
      bool boons = false,
      int? seed,
      String? daily,
      String? difficulty}) {
    // Deterministic-enough seed for real play; runs are still fully replayable
    // from their seed. Daily runs pin [seed] via [startDailyRun].
    final s = seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    sim = Sim(s);
    _bankedThisRun = false;
    dailyDate = daily;
    // Daily Delve is a shared-seed leaderboard-of-honor: everyone plays the
    // exact same delve, so it always runs on normal (spec §Ethics fairness).
    final diff =
        daily != null ? 'normal' : (difficulty ?? meta.preferredDifficulty);
    apply({
      'type': 'start_run',
      if (character != null) 'character': character,
      'ascension': ascension,
      if (boons) 'boons': true,
      if (diff != 'normal') 'difficulty': diff,
    });
  }

  /// Sticky difficulty preference behind the title-screen selector.
  /// Any explicit tap — even on the already-selected segment — counts as a
  /// choice and ends the first-run easy steering for good.
  void setPreferredDifficulty(String d) {
    if (!const {'easy', 'normal', 'hard'}.contains(d)) return;
    if (meta.preferredDifficulty == d && meta.difficultyChosen) return;
    meta.preferredDifficulty = d;
    meta.difficultyChosen = true;
    MetaStore.save(meta);
    notifyListeners();
  }

  /// Buy a hearth color with embers (v0.3.3 ledger cosmetics).
  bool buyTheme(String id) {
    final ok = meta.tryBuyTheme(id);
    if (ok) {
      MetaStore.save(meta);
      audio?.playSfx('unlock');
    }
    notifyListeners();
    return ok;
  }

  /// Activate an owned hearth color (sticky).
  void setActiveTheme(String id) {
    if (!meta.ownedThemes.contains(id) || meta.activeTheme == id) return;
    meta.activeTheme = id;
    MetaStore.save(meta);
    notifyListeners();
  }

  /// Daily Delve: everyone starts from the same seed for the device's local
  /// calendar date (same map, same offers, same boon offering). No streaks,
  /// no expiry — just a shared delve (spec §Ethics).
  void startDailyRun({String? character}) {
    final now = DateTime.now();
    final label = dailyKey(now);
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
        boons: true,
        difficulty: run?['difficulty'] as String? ?? 'normal');
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
    recordCombatStats(events);
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
    // v0.3.1 F5: events used to resolve with zero feedback — you only found
    // out what the ghost took mid-fight. Summarize the concrete effects.
    if (events.any((e) => e['type'] == 'event_resolved')) {
      final summary = _eventSummary(events);
      if (summary != null) {
        flash = summary;
        return;
      }
    }
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

  /// One-line outcome of an event choice, from its effect events.
  String? _eventSummary(List<Map<String, Object?>> events) {
    final parts = <String>[];
    String dieName(Object? id) =>
        id is String ? dieDef(id).name : 'a die';
    for (final e in events) {
      switch (e['type']) {
        case 'die_lost':
          parts.add('Lost ${dieName(e['die'])}');
          break;
        case 'die_gained':
          parts.add('Gained ${dieName(e['die'])}');
          break;
        case 'relic_gained':
          final id = e['relic'];
          parts.add('Relic: ${id is String ? relicDef(id).name : 'gained'}');
          break;
        case 'gold_gained':
          parts.add('+${e['amount']} gold');
          break;
        case 'gold_spent':
          parts.add('−${e['amount']} gold');
          break;
        case 'hp_lost':
          parts.add('−${e['amount']} HP');
          break;
        case 'healed':
          if ((e['amount'] as int? ?? 0) > 0) {
            parts.add('+${e['amount']} HP');
          }
          break;
        case 'max_hp_changed':
          final a = e['amount'] as int? ?? 0;
          parts.add('${a > 0 ? '+' : ''}$a max HP');
          break;
        case 'embers_gained':
          parts.add('+${e['amount']} embers');
          break;
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// v0.3.1 F11: persist that the first-fight tutorial has been seen.
  void markTutorialSeen() {
    if (meta.tutorialSeen) return;
    meta.tutorialSeen = true;
    MetaStore.save(meta);
  }

  /// v0.3.1 F10: voluntary mid-run exit from the pause menu. Discards the
  /// run and its save without banking (death banks half + floor; walking
  /// away banks nothing) but still counts the run as played.
  void abandonRun() {
    if (sim == null) return;
    meta.runsPlayed += 1;
    final char = sim!.run?['character'] as String? ?? defaultCharacter;
    meta.charRuns[char] = (meta.charRuns[char] ?? 0) + 1;
    MetaStore.save(meta);
    _clearSave();
    sim = null;
    dailyDate = null;
    _bankedThisRun = false;
    notifyListeners();
    _syncAudio();
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

  /// v0.3.3 ledger stats: lifetime exact-kill count and the exact-kill
  /// streak (consecutive fights ended with an exact kill; a fight won any
  /// other way resets it). Pure observation of sim events — the sim itself
  /// stays untouched. Persistence rides the next _bankRun/autosave cycle;
  /// on a fight won we save immediately so a crash can't eat a streak.
  @visibleForTesting
  void recordCombatStats(List<Map<String, Object?>> events) {
    final exact = events.any((e) => e['type'] == 'exact_kill');
    final fightWon = events.any((e) => e['type'] == 'encounter_won');
    if (exact) meta.exactKills += 1;
    if (!fightWon) return;
    meta.exactStreak = exact ? meta.exactStreak + 1 : 0;
    if (meta.exactStreak > meta.bestExactStreak) {
      meta.bestExactStreak = meta.exactStreak;
    }
    MetaStore.save(meta);
  }

  void _bankRun() {
    if (_bankedThisRun || sim == null) return;
    _bankedThisRun = true;
    final run = sim!.run;
    if (run == null) return;
    final banked = run['embers'] as int? ?? 0;
    final char = run['character'] as String? ?? defaultCharacter;
    meta.embers += banked;
    meta.lifetimeEmbers += banked;
    meta.runsPlayed += 1;
    meta.charRuns[char] = (meta.charRuns[char] ?? 0) + 1;
    if (sim!.phase == 'run_won') {
      meta.runsWon += 1;
      meta.charWins[char] = (meta.charWins[char] ?? 0) + 1;
      final asc = run['ascension'] as int? ?? 0;
      if (asc >= meta.bestAscension) meta.bestAscension = asc + 1;
    }
    // Daily Delve record (v0.3.4): only a FINISHED daily counts as played —
    // abandoning mid-run records nothing. One record, no history/streaks.
    if (dailyDate != null) {
      meta.lastDailyDate = dailyDate;
      meta.lastDailyWon = sim!.phase == 'run_won';
      meta.lastDailyFloor = floorReached;
      meta.lastDailyFloors = (sim!.map?['layers'] as int?) ?? 0;
    }
    MetaStore.save(meta);
    _clearSave();
  }

  /// 1-based map layer of the node the run currently stands on (the boss
  /// layer after a win, the death layer after a loss). 0 when unknown.
  int get floorReached {
    final map = sim?.map;
    if (map == null) return 0;
    final node = (map['nodes'] as Map?)?['${map['position']}'] as Map?;
    return node?['layer'] as int? ?? 0;
  }

  /// Share text for a just-finished Daily Delve; null for normal runs or
  /// mid-run. Built from the banked meta record so it matches what the
  /// title recap will show.
  String? get dailyResultShareText {
    if (dailyDate == null || meta.lastDailyDate != dailyDate) return null;
    if (!_terminal.contains(sim?.phase) || sim?.phase == 'idle') return null;
    return dailyShareText(
      date: meta.lastDailyDate!,
      won: meta.lastDailyWon,
      floor: meta.lastDailyFloor,
      floors: meta.lastDailyFloors,
    );
  }

  /// Surface a toast from UI actions that don't go through the sim
  /// (e.g. "Result copied").
  void announce(String message) {
    flash = message;
    notifyListeners();
  }

  /// Chained on the same queue as [_autosave], so a pending queued save can
  /// never resurrect a run the player just abandoned or finished.
  Future<void> _clearSave() {
    _saveQueue = _saveQueue.then((_) async {
      try {
        final f = await _runFile();
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });
    return _saveQueue;
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
