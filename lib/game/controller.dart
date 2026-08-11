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
import '../telemetry/telemetry_service.dart';
import '../data/dice.dart';
import '../data/relics.dart';
import '../data/enemies.dart';
import '../meta/achievements.dart';
import '../meta/forge.dart';
import '../meta/meta.dart';
import '../sim/daily.dart';
import '../sim/hashing.dart';
import '../sim/sim.dart';
import 'daily_share.dart';

class GameController extends ChangeNotifier {
  Sim? sim;
  MetaState meta = MetaState();

  // -------------------------------------------------------------------------
  // Per-field change ticks (perf, v0.3.15)
  //
  // This controller is a single ChangeNotifier, so `GameRoot` rebuilt the WHOLE
  // active screen on every notifyListeners() — a die roll re-ran the combat
  // screen's ~1000-line build() including the top bar, the enemy panel and the
  // sprite stage, none of which read the dice. Scoping rebuilds *inside* the
  // screens hit that ceiling (measured 1.7x and stuck).
  //
  // These notifiers fire only when the field they name actually changed value,
  // detected by hashing the field after every notification (the sim's own
  // deterministic hasher, `hashValue`). Because the detection hangs off an
  // override of [notifyListeners], EVERY existing mutation path feeds them —
  // there is no second place to remember to bump.
  //
  // Screens may listen to `this` (whole-screen rebuild, unchanged behaviour) or
  // to the ticks they actually read. Ticks are never a substitute for reading
  // state: consumers still read `state()` when they rebuild.
  final ValueNotifier<int> phaseTick = ValueNotifier(0);
  final ValueNotifier<int> turnTick = ValueNotifier(0);
  final ValueNotifier<int> runTick = ValueNotifier(0);
  final ValueNotifier<int> enemyTick = ValueNotifier(0);

  /// Player HP / max HP / block only — NOT the dice.
  final ValueNotifier<int> playerVitalsTick = ValueNotifier(0);

  /// The dice pool and everything about this turn's roll: faces, assignment,
  /// maxed flags, rerolls left, risky/free reroll state.
  final ValueNotifier<int> diceTick = ValueNotifier(0);

  /// Delve map (nodes, position) — the map screen's data.
  final ValueNotifier<int> mapTick = ValueNotifier(0);

  /// Meta/profile state (embers, unlocks, theme, tutorial flag).
  final ValueNotifier<int> metaTick = ValueNotifier(0);

  static const _vitalKeys = ['hp', 'max_hp', 'block'];
  static const _diceKeys = [
    'dice',
    'rolled',
    'rolled_max',
    'assigned',
    'rerolls_left',
    'risky_used',
    'free_reroll',
  ];

  final Map<String, int> _tickHash = {};

  /// Bump [tick] when the hash of [value] changed since the last check.
  void _syncTick(String key, ValueNotifier<int> tick, Object? value) {
    final h = hashValue(17, value);
    final prev = _tickHash[key];
    if (prev == h) return;
    _tickHash[key] = h;
    // First observation seeds the hash without firing: nobody is listening to
    // a value they have not read yet, and a spurious first tick would rebuild
    // the very subtree that just built.
    if (prev != null) tick.value++;
  }

  Map<String, Object?> _subset(Map? src, List<String> keys) => {
    for (final k in keys)
      if (src != null && src[k] != null) k: src[k],
  };

  @override
  void notifyListeners() {
    final st = sim?.state();
    final player = st?['player'] as Map?;
    _syncTick('phase', phaseTick, sim?.phase ?? 'none');
    _syncTick('turn', turnTick, st?['turn']);
    _syncTick('run', runTick, st?['run']);
    _syncTick('enemy', enemyTick, st?['enemy']);
    _syncTick('vitals', playerVitalsTick, _subset(player, _vitalKeys));
    _syncTick('dice', diceTick, _subset(player, _diceKeys));
    _syncTick('map', mapTick, st?['map']);
    _syncTick('meta', metaTick, meta.toJson());
    super.notifyListeners();
  }

  @override
  void dispose() {
    phaseTick.dispose();
    turnTick.dispose();
    runTick.dispose();
    enemyTick.dispose();
    playerVitalsTick.dispose();
    diceTick.dispose();
    mapTick.dispose();
    metaTick.dispose();
    super.dispose();
  }

  /// Wired by main(); null in tests, so gameplay never depends on audio.
  AudioService? audio;
  String? flash; // transient toast (invalid reasons, rewards, heals)

  /// Overkill splash that softened the enemy the current encounter opened
  /// with (LFP-6a). Set by the splash_damage event, claimed exactly once by
  /// the combat screen so it can call the dent out on the stage itself.
  int? _splashIn;
  int? takeSplashIn() {
    final v = _splashIn;
    _splashIn = null;
    return v;
  }

  bool _bankedThisRun = false;
  // v0.5.0 Delver's Ledger observation. Both are per-RUN scratch, reset with
  // _bankedThisRun, and both are read from sim EVENTS only — the sim is not
  // touched. _lastEnemyId is the enemy of the encounter in progress, which on
  // a win is by definition the boss that just fell.
  String? _lastEnemyId;
  bool _restedThisRun = false;
  /// Achievements earned by the run that just ended and not yet announced.
  /// The summary screen renders it in the same breath as the run result;
  /// [startRun] clears it. Nothing else may write it.
  List<String> pendingAchievements = const [];

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
    // Ember Forge migration (v0.4.0): a pre-Forge profile may have HARD as
    // its sticky preference. The clamp in startRun would already force
    // normal; also move the VISIBLE selector so what's highlighted is what
    // they get (same no-silent-switch rule as the easy steering below).
    if (!meta.forgeUnlocked && meta.preferredDifficulty == 'hard') {
      meta.preferredDifficulty = 'normal';
    }
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
          _lastEnemyId = null;
          _restedThisRun = false;
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

  void _syncAudio() {
    audio?.syncPhase(phase, bossFight: _bossFight);
    audio?.setDanger(_inDanger);
  }

  /// Low-HP danger bed condition: mid-combat with HP at or under 30% of max.
  /// Computed here (not in the audio layer) so the rule stays gameplay-owned
  /// and testable without audio.
  bool get _inDanger {
    if (phase != 'player_turn') return false;
    final p = sim?.player;
    if (p == null) return false;
    final hp = p['hp'] as int? ?? 0;
    final maxHp = p['max_hp'] as int? ?? 1;
    return hp * 10 <= maxHp * 3;
  }

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

  /// Test seam (tool/play_session_test.dart): when set, the next [startRun]
  /// without an explicit [seed] consumes this value instead of the clock, so
  /// harness runs are reproducible from a command line. One-shot: cleared on
  /// use. Never set by production UI code.
  int? debugNextRunSeed;

  void startRun({
    String? character,
    int ascension = 0,
    bool boons = false,
    int? seed,
    String? daily,
    String? difficulty,
  }) {
    // Deterministic-enough seed for real play; runs are still fully replayable
    // from their seed. Daily runs pin [seed] via [startDailyRun]; the play
    // harness pins it via [debugNextRunSeed] (one-shot override).
    final s = seed ??
        debugNextRunSeed ??
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    debugNextRunSeed = null;
    sim = Sim(s);
    _bankedThisRun = false;
    _lastEnemyId = null;
    _restedThisRun = false;
    // The last run's announcements are done with; a stale list must never
    // resurface on the next summary.
    pendingAchievements = const [];
    dailyDate = daily;
    // Daily Delve is a shared-seed leaderboard-of-honor: everyone plays the
    // exact same delve, so it always runs on normal (spec §Ethics fairness).
    // Ember Forge gate (v0.4.0, spec R8): UI locks are the polite layer;
    // this clamp is the guarantee. Daily runs are pinned to normal above.
    final wanted = daily != null
        ? 'normal'
        : (difficulty ?? meta.preferredDifficulty);
    final allowed =
        clampRunParams(meta, difficulty: wanted, ascension: ascension);
    final diff = allowed.difficulty;
    apply({
      'type': 'start_run',
      if (character != null) 'character': character,
      'ascension': allowed.ascension,
      if (boons) 'boons': true,
      if (diff != 'normal') 'difficulty': diff,
    });
    // Opt-in analytics only; no-op without consent (docs/telemetry-events.md).
    TelemetryService.instance.logEvent('run_started', {
      'character': character ?? defaultCharacter,
      'ascension': '$ascension',
      'difficulty': diff,
      'daily': '${daily != null}',
    });
  }

  /// Sticky difficulty preference behind the title-screen selector.
  /// Any explicit tap — even on the already-selected segment — counts as a
  /// choice and ends the first-run easy steering for good.
  void setPreferredDifficulty(String d) {
    if (!const {'easy', 'normal', 'hard'}.contains(d)) return;
    if (!canSelectDifficulty(meta, d)) return; // Forge-locked (v0.4.0)
    if (meta.preferredDifficulty == d && meta.difficultyChosen) return;
    meta.preferredDifficulty = d;
    meta.difficultyChosen = true;
    MetaStore.save(meta);
    notifyListeners();
  }

  /// Grant the Ember Forge entitlement (purchase or restore confirmed by
  /// Play Billing — see meta/store_service.dart). Idempotent; persists via
  /// the same queued, atomic MetaStore.save as every other meta mutation.
  Future<void> grantForgeUnlock() async {
    if (meta.forgeUnlocked) return;
    meta.forgeUnlocked = true;
    audio?.playSfx('unlock');
    notifyListeners();
    await MetaStore.save(meta);
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
      daily: label,
    );
  }

  /// Fast restart from the death/victory ledger: a new run (fresh seed) with
  /// the same delver and ascension, straight into the boon pick.
  void delveAgain() {
    final run = sim?.run;
    startRun(
      character: run?['character'] as String?,
      ascension: run?['ascension'] as int? ?? 0,
      boons: true,
      difficulty: run?['difficulty'] as String? ?? 'normal',
    );
  }

  /// The ONLY mutation path. Applies, banks on terminal, autosaves, flashes.
  ///
  /// [terminalHold]: when the command ends the encounter (won or lost), delay
  /// the rebuild-notify by this long so the combat screen can finish its death
  /// choreography before the phase switches. State/saves update immediately;
  /// only the listener notification (and music change) is held.
  List<Map<String, Object?>> apply(
    Map<String, Object?> cmd, {
    Duration? terminalHold,
  }) {
    if (sim == null) return const [];
    final events = sim!.apply(cmd);
    _handleFlash(events);
    recordCombatStats(events);
    if (_terminal.contains(sim!.phase)) _bankRun();
    _autosave();
    audio?.handleEvents(events);
    final ended = events.any(
      (e) => e['type'] == 'encounter_won' || e['type'] == 'encounter_lost',
    );
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
          // "Move on" from a full-HP rest heals 0 — no toast for a non-heal.
          final healed = e['healed'];
          if (healed is int && healed > 0) {
            flash = 'Rested — healed $healed HP';
          }
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
          // LFP-6a (corrected diagnosis): the "Wisp spawns at 19/20" playtest
          // finding is overkill splash carry-in working as designed — there is
          // no floor-vs-round mismatch (combatBegin rounds hp and max_hp from
          // the same value). What was broken is LEGIBILITY: this toast fired
          // during the map→combat flame wipe and was gone before the stage
          // was readable, so the dented HP bar looked like a bug. The combat
          // screen now claims the amount and shows an on-enemy call-out once
          // the stage is up.
          _splashIn = e['amount'] as int?;
          break;
      }
    }
  }

  /// One-line outcome of an event choice, from its effect events.
  String? _eventSummary(List<Map<String, Object?>> events) {
    final parts = <String>[];
    String dieName(Object? id) => id is String ? dieDef(id).name : 'a die';
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
    meta.addRunRecord(_runRecord(result: 'abandoned', embers: 0));
    // Opt-in analytics only; no-op without consent (docs/telemetry-events.md).
    TelemetryService.instance.logEvent('run_ended', {
      'result': 'abandoned',
      'character': char,
      'floor': '$floorReached',
      'embers': '0',
    });
    MetaStore.save(meta);
    _clearSave();
    sim = null;
    dailyDate = null;
    _bankedThisRun = false;
    _lastEnemyId = null;
    _restedThisRun = false;
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

  /// v0.5.0 Delver's Ledger observation: remember which enemy is being fought
  /// and whether this run has rested. Both are pure event observation, so the
  /// sealed sim and the golden hash are untouched.
  @visibleForTesting
  void recordLedgerStats(List<Map<String, Object?>> events) {
    for (final e in events) {
      switch (e['type']) {
        case 'encounter_started':
          final id = e['enemy'];
          if (id is String) _lastEnemyId = id;
          break;
        case 'rested':
          // Any visit to a rest node counts, even a 0 HP "move on" — the
          // achievement is about skipping the node, not about the heal.
          _restedThisRun = true;
          break;
      }
    }
  }

  /// v0.3.3 ledger stats: lifetime exact-kill count and the exact-kill
  /// streak (consecutive fights ended with an exact kill; a fight won any
  /// other way resets it). Pure observation of sim events — the sim itself
  /// stays untouched. Persistence rides the next _bankRun/autosave cycle;
  /// on a fight won we save immediately so a crash can't eat a streak.
  @visibleForTesting
  void recordCombatStats(List<Map<String, Object?>> events) {
    recordLedgerStats(events);
    final exact = events.any((e) => e['type'] == 'exact_kill');
    final fightWon = events.any((e) => e['type'] == 'encounter_won');
    if (exact) meta.exactKills += 1;
    // A lost fight breaks the row: "N fights in a row on exact kills" must
    // never span a death (§Ethics honesty — the ledger cannot credit a streak
    // the player visibly broke). Persistence rides the _bankRun save that
    // follows every terminal phase.
    if (events.any((e) => e['type'] == 'encounter_lost')) {
      meta.exactStreak = 0;
    }
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
      // Best ascension = highest rung unlocked; a win at rung N opens N+1.
      // The ladder tops out at rung 20 (forge.dart clamps the same), so a
      // win at 20 must not mint a rung 21 in the ledger.
      if (asc >= meta.bestAscension) {
        meta.bestAscension = (asc + 1).clamp(0, 20);
      }
    }
    // Daily Delve record (v0.3.4): only a FINISHED daily counts as played —
    // abandoning mid-run records nothing. One record, no history/streaks.
    if (dailyDate != null) {
      meta.lastDailyDate = dailyDate;
      meta.lastDailyWon = sim!.phase == 'run_won';
      meta.lastDailyFloor = floorReached;
      meta.lastDailyFloors = (sim!.map?['layers'] as int?) ?? 0;
    }
    // v0.5.0 Delver's Ledger counters. All banked from what actually happened
    // this run: the deepest layer stood on, a finished daily, a win with no
    // rest node visited, a win on hard, and the boss id that fell.
    final reached = floorReached;
    if (reached > meta.bestFloor) meta.bestFloor = reached;
    if (dailyDate != null) meta.dailiesPlayed += 1;
    if (sim!.phase == 'run_won') {
      if (!_restedThisRun) meta.winsNoRest += 1;
      if ((run['difficulty'] as String? ?? 'normal') == 'hard') {
        meta.hardWins += 1;
      }
      // The encounter in progress at a win is the boss by construction. Guard
      // on the roster anyway so a future enemy id can never poison the set.
      final boss = _lastEnemyId;
      if (boss != null && (enemies[boss]?.boss ?? false)) {
        meta.bossesBeaten.add(boss);
      }
    }
    // Run history (v0.3.4): one small record per ended run, newest first.
    meta.addRunRecord(
      _runRecord(
        result: sim!.phase == 'run_won' ? 'won' : 'lost',
        embers: banked,
      ),
    );
    // Opt-in analytics only; no-op without consent (docs/telemetry-events.md).
    TelemetryService.instance.logEvent('run_ended', {
      'result': sim!.phase == 'run_won' ? 'won' : 'lost',
      'character': char,
      'floor': '$floorReached',
      'embers': '$banked',
    });
    // Newly earned achievements are collected AFTER every counter above is
    // banked, so the summary screen can announce them in the same breath as
    // the run result. markSeen keeps a toast from ever firing twice.
    final fresh = unseenAchievements(meta);
    if (fresh.isNotEmpty) {
      pendingAchievements = fresh;
      markSeen(meta, fresh);
    }
    MetaStore.save(meta);
    _clearSave();
  }

  Map<String, Object?> _runRecord({
    required String result,
    required int embers,
  }) {
    final run = sim?.run;
    return {
      'date': dailyKey(DateTime.now()),
      'character': run?['character'] as String? ?? defaultCharacter,
      'difficulty': run?['difficulty'] as String? ?? 'normal',
      'ascension': run?['ascension'] as int? ?? 0,
      'result': result,
      'floor': floorReached,
      'floors': sim?.map?['layers'] as int? ?? 0,
      'seed': sim?.runSeed ?? 0,
      'embers': embers,
      if (dailyDate != null) 'daily': true,
    };
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
