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
import '../data/news.dart';
import '../telemetry/telemetry_service.dart';
import '../data/dice.dart';
import 'tips.dart';
import 'tour.dart';
import '../data/relics.dart';
import '../data/enemies.dart';
import '../meta/achievements.dart';
import '../meta/forge.dart';
import '../meta/meta.dart';
import '../meta/play_games_service.dart';
import '../meta/review_service.dart';
import '../meta/rank.dart';
import '../sim/daily.dart';
import '../sim/hashing.dart';
import '../sim/keystones.dart';
import '../sim/run_dice.dart';
import '../sim/sim.dart';
import 'daily_share.dart';
import 'trials.dart';
import 'run_trace.dart';
import 'weekly.dart';

class GameController extends ChangeNotifier {
  Sim? sim;
  MetaState meta = MetaState();

  /// v0.10.0 The First Delve: staged contextual tip state. Rebuilt at boot
  /// so it always shares the loaded meta's tipsSeen set (see tips.dart).
  late TipDirector tipDirector = TipDirector(meta.tipsSeen);
  // v0.8.0 The Guided Delve: anchored tour. Recreated on boot; runs when
  // meta.tourSeenVersion < tourVersion, or on demand via requestTourReplay.
  late TourDirector tour = TourDirector(seenVersion: meta.tourSeenVersion);

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
    'rolled_face',
    'surge_used',
    'echo_pending',
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

  // v0.11.0 Delver's Ledger: enemy ids whose lifetime met/felled record went
  // 0 -> 1 during THIS run ("First sighting" / "First felling" on the
  // summary). Run-scoped; persisted beside the snapshot ('run_firsts') so a
  // killed-and-resumed run keeps its firsts honest.
  final Set<String> runFirstMet = {};
  final Set<String> runFirstFelled = {};
  bool _restedThisRun = false;

  /// v0.8.0 spoiler-free floor trace for share text. Per-run scratch like
  /// the ledger fields above: reset in [startRun], fed from sim events in
  /// [apply], persisted beside the snapshot ('run_trace') like run_labels.
  RunTrace runTrace = RunTrace();

  /// Achievements earned by the run that just ended and not yet announced.
  /// The summary screen renders it in the same breath as the run result;
  /// [startRun] clears it. Nothing else may write it.
  List<String> pendingAchievements = const [];

  /// The Delver's Rank tier this run's banking crossed INTO, if any
  /// (v0.13.0). Rank is derived (meta/rank.dart), so this is just a
  /// before/after comparison made inside [_bankRun]; the summary shows one
  /// quiet line and [startRun] clears it. Nothing else may write it.
  RankTier? pendingRankUp;

  /// The Ascension rung this run's win just opened, if any (v0.32.0, hook
  /// #7). Set inside [_bankRun] only when the win actually raised
  /// [MetaState.bestAscension] (a frontier win below the rung-20 cap);
  /// cleared by [startRun]. Derived announcement state — never persisted,
  /// same contract as [pendingRankUp]. The summary additionally gates the
  /// line on forgeUnlocked: a free profile's first win moves bestAscension
  /// 0→1 but cannot use rung 1, and announcing it would be a soft upsell
  /// (§Ethics — see docs/improvements/v0.32.0-open-rung-design.md).
  int? pendingRungOpened;

  /// 'YYYY-MM-DD' while the current run is a Daily Delve; null otherwise.
  /// Persisted alongside the sim snapshot ('run_labels') and restored by
  /// [boot], because [_bankRun] gates the daily record on it — a resumed
  /// daily must still record its result when it ends.
  String? dailyDate;

  /// Week index while the current run is a Weekly Delve; null otherwise.
  /// The run's mutators live in the sim and survive save/restore on their
  /// own; this label is persisted with the save too ('run_labels') so a
  /// resumed weekly still banks its record and shows its badge.
  int? weeklyIndex;
  String? weeklyMutator; // the modifier id this weekly is running under

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
    tipDirector = TipDirector(meta.tipsSeen);
    tour = TourDirector(seenVersion: meta.tourSeenVersion);
    // v0.6.1: HARD is Forge-gated again (free only during v0.6.0). A locked
    // profile whose sticky preference says 'hard' (set while 0.6.0 was live)
    // is moved back to 'normal' HERE, on the visible selector — the player
    // sees what they'll get; startRun's clamp stays as the guarantee.
    if (!meta.forgeUnlocked && meta.preferredDifficulty == 'hard') {
      meta.preferredDifficulty = 'normal';
    }
    // First-run on-ramp (v0.3.3): steer a brand-new profile toward easy by
    // moving the VISIBLE selector — what's highlighted is what they get, so
    // there is never a silent difficulty switch. One tap ends the steering.
    if (meta.steerToEasy) meta.preferredDifficulty = 'easy';
    // v0.15.0 Hearthside Post: a brand-new profile has no "before" to
    // compare against, so stamp the current version silently — the first
    // post a new player ever sees is the first update they live through.
    // A veteran save ('' but runs played) keeps '' and sees the note.
    if (meta.lastSeenNewsVersion.isEmpty && meta.runsPlayed == 0) {
      meta.lastSeenNewsVersion = currentAppVersion;
      MetaStore.save(meta);
    }
    // v0.33.0 Gramophone: every profile that reaches the title screen has
    // heard the hearth theme — seed it here so legacy saves need no
    // migration. Saved lazily with whatever save happens next; seeding alone
    // is not worth a disk write on every boot.
    meta.heardTracks.add('title_menu');
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
          // Restore the run-identity labels saved by _autosave, so a resumed
          // Daily/Weekly Delve still banks its record (and shows its badge)
          // when it ends. Absent on normal runs and on pre-fix saves.
          final labels = snap['run_labels'];
          if (labels is Map) {
            dailyDate = labels['daily'] as String?;
            weeklyIndex = (labels['weekly_index'] as num?)?.toInt();
            weeklyMutator = labels['weekly_mutator'] as String?;
          }
          // v0.8.0: the floor trace rides the same side channel — a resumed
          // run keeps its earlier floors, or starts clean on pre-fix saves.
          runTrace = RunTrace.fromJson(snap['run_trace']);
          // v0.11.0: this run's first-sighting/first-felling record.
          runFirstMet.clear();
          runFirstFelled.clear();
          final firsts = snap['run_firsts'];
          if (firsts is Map) {
            runFirstMet.addAll(
              ((firsts['met'] as List?) ?? const []).whereType<String>(),
            );
            runFirstFelled.addAll(
              ((firsts['felled'] as List?) ?? const []).whereType<String>(),
            );
          }
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
    audio?.syncPhase(phase, bossFight: _bossFight, mapDepth: mapDepth);
    audio?.setDanger(_inDanger);
    // v0.33.0 Gramophone: record which tracks this profile has heard. The
    // key is computed from the SAME static rule the audio layer uses, so the
    // record is gameplay-owned and testable with audio == null — the exact
    // split _inDanger and mapDepth already follow. Only mid-run phases are
    // recorded here ('title_menu' is seeded in boot); saves only when the
    // set actually grows.
    if (sim != null) {
      final key = AudioService.musicKeyForPhase(phase, bossFight: _bossFight);
      if (key != null && key != 'title_menu' && meta.heardTracks.add(key)) {
        MetaStore.save(meta);
      }
    }
  }

  /// Descent depth for the Deep Hum ambience (v0.23.0): 0.0 on the first
  /// layer, 1.0 on the boss layer. Computed here (not in the audio layer) so
  /// the rule stays gameplay-owned and testable without audio — same split
  /// as [_inDanger].
  double get mapDepth {
    final st = sim?.state();
    final map = st?['map'] as Map?;
    if (map == null) return 0;
    final layers = map['layers'] as int? ?? 0;
    if (layers <= 1) return 0;
    final node = (map['nodes'] as Map?)?['${map['position']}'] as Map?;
    final layer = node?['layer'] as int? ?? 1;
    return (layer - 1) / (layers - 1);
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
    final snapMap = sim!.snapshot();
    // Run-identity labels ride ALONGSIDE the sim snapshot (Sim.restore reads
    // only its own keys, so this is invisible to the sim). Without them a
    // Daily/Weekly Delve that is killed and resumed finished as a plain run:
    // _bankRun gates every daily/weekly record on these fields, so the recap,
    // the share button and the played-counters silently vanished (bug-hunt
    // 2026-08-11). Only stamped when set, so normal-run save blobs stay
    // byte-identical.
    if (runFirstMet.isNotEmpty || runFirstFelled.isNotEmpty) {
      snapMap['run_firsts'] = {
        'met': runFirstMet.toList()..sort(),
        'felled': runFirstFelled.toList()..sort(),
      };
    }
    if (dailyDate != null || weeklyIndex != null) {
      snapMap['run_labels'] = {
        if (dailyDate != null) 'daily': dailyDate,
        if (weeklyIndex != null) 'weekly_index': weeklyIndex,
        if (weeklyMutator != null) 'weekly_mutator': weeklyMutator,
      };
    }
    // v0.8.0: floor trace rides the same side channel (invisible to the
    // sim). Only stamped once a floor exists, so a fresh run's first save
    // blob stays identical to pre-0.8.0 bytes.
    if (!runTrace.isEmpty) snapMap['run_trace'] = runTrace.toJson();
    final snap = jsonEncode(snapMap);
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

  /// Test seam: await every queued save/clear (the queue is otherwise
  /// private). Production code never needs this — writes are ordered.
  @visibleForTesting
  Future<void> flushSaves() => _saveQueue;

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
    List<String> mutators = const [],
  }) {
    // Deterministic-enough seed for real play; runs are still fully replayable
    // from their seed. Daily runs pin [seed] via [startDailyRun]; the play
    // harness pins it via [debugNextRunSeed] (one-shot override).
    final s =
        seed ??
        debugNextRunSeed ??
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    debugNextRunSeed = null;
    sim = Sim(s);
    _bankedThisRun = false;
    _lastEnemyId = null;
    _restedThisRun = false;
    runFirstMet.clear();
    runFirstFelled.clear();
    // v0.8.0: every fresh run traces from floor zero — a stale trace must
    // never leak a previous run's floors into this run's share text.
    runTrace = RunTrace();
    // The last run's announcements are done with; a stale list must never
    // resurface on the next summary.
    pendingAchievements = const [];
    pendingRankUp = null;
    pendingRungOpened = null;
    dailyDate = daily;
    // Weekly badge/banking labels are set by [startWeeklyRun]; any other
    // entry point (normal, daily, restart) clears them so a fresh run never
    // inherits a stale weekly badge or banks against the wrong week.
    weeklyIndex = null;
    weeklyMutator = null;
    // Daily and Weekly Delves are shared-seed challenges: everyone plays the
    // exact same delve, so they always run on normal (spec §Ethics fairness).
    // The modifier IS the difficulty knob for the weekly. Ember Forge gate
    // (v0.4.0, spec R8): UI locks are the polite layer; this clamp is the
    // guarantee. Shared runs are pinned to normal above.
    final shared = daily != null || mutators.isNotEmpty;
    final wanted = shared ? 'normal' : (difficulty ?? meta.preferredDifficulty);
    final allowed = clampRunParams(
      meta,
      difficulty: wanted,
      ascension: ascension,
    );
    final diff = allowed.difficulty;
    apply({
      'type': 'start_run',
      if (character != null) 'character': character,
      'ascension': allowed.ascension,
      if (boons) 'boons': true,
      if (diff != 'normal') 'difficulty': diff,
      if (mutators.isNotEmpty) 'mutators': mutators,
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

  /// v0.15.0 Hearthside Post: the player tapped "Noted" on the title-screen
  /// news panel. Sticky per version — the note never returns for this
  /// release, and cloud merge keeps the larger version (cloud_merge.dart).
  void dismissNews() {
    if (meta.lastSeenNewsVersion == currentAppVersion) return;
    meta.lastSeenNewsVersion = currentAppVersion;
    MetaStore.save(meta);
    audio?.playSfx('ui_tap');
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

  // v0.4.3 P1 ember sink — dice skins + Codex, same shape as hearth colors:
  // meta owns the rules (price, dedupe), the controller owns persistence,
  // sfx, and notification. Pure cosmetics/lore — the sim never sees any of it.
  bool buyDieSkin(String id) {
    final ok = meta.tryBuyDieSkin(id);
    if (ok) {
      MetaStore.save(meta);
      audio?.playSfx('unlock');
    }
    notifyListeners();
    return ok;
  }

  void setActiveDieSkin(String id) {
    if (!meta.ownedDieSkins.contains(id) || meta.activeDieSkin == id) return;
    meta.activeDieSkin = id;
    MetaStore.save(meta);
    notifyListeners();
  }

  // v0.27.0 The Delver's Wardrobe — delver dyes, same shape as dice skins.
  bool buyDye(String id) {
    final ok = meta.tryBuyDye(id);
    if (ok) {
      MetaStore.save(meta);
      audio?.playSfx('unlock');
    }
    notifyListeners();
    return ok;
  }

  void setActiveDye(String id) {
    if (!meta.ownedDyes.contains(id) || meta.activeDye == id) return;
    meta.activeDye = id;
    MetaStore.save(meta);
    notifyListeners();
  }

  bool buyCodexEntry(String id) {
    final ok = meta.tryBuyCodex(id);
    if (ok) {
      MetaStore.save(meta);
      audio?.playSfx('unlock');
    }
    notifyListeners();
    return ok;
  }

  /// Daily Delve: everyone starts from the same seed for the device's local
  /// calendar date (same map, same offers, same boon offering). No streaks,
  /// no expiry — just a shared delve (spec §Ethics).
  /// [clock] pins the date in tests; production always plays today.
  void startDailyRun({String? character, DateTime? clock}) {
    final now = clock ?? DateTime.now();
    final label = dailyKey(now);
    // v0.9.0 Today's Trials: the date deterministically declares ONE trial.
    // A mutator day rides the existing cmd['mutators'] seam (sim-known ids
    // only); a goal day changes nothing here — it is judged at bank time.
    final trial = trialForDate(now.year, now.month, now.day);
    startRun(
      character: character,
      seed: dailySeed(now.year, now.month, now.day),
      boons: true,
      daily: label,
      mutators: trial.mutators,
    );
  }

  /// Weekly Delve: everyone plays the same seed AND the same declared
  /// modifier for the current Monday-aligned week (spec §Ethics — a shared
  /// challenge, no streaks, no expiry). The modifier is picked deterministic-
  /// ally from the week index, so the whole player base sees the same rule.
  void startWeeklyRun({String? character}) {
    final now = DateTime.now();
    final index = weekIndexForDate(now);
    final mutator = weeklyMutatorFor(index);
    // The seed MUST be pinned to the week (bug-hunt 2026-08-11): weeklySeed
    // existed and was unit-tested but was never wired in here, so every
    // player got a random clock seed — "one shared delve" was only sharing
    // the modifier, and the share text's shared-seed claim was false.
    startRun(
      character: character,
      seed: weeklySeed(index),
      boons: true,
      mutators: [mutator],
    );
    // startRun clears the weekly labels, so stamp them AFTER it returns.
    weeklyIndex = index;
    weeklyMutator = mutator;
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

  /// Post-Easy-win invitation (v0.29.0, retention hook #3): a fresh run on
  /// NORMAL with the same delver — the summary's quiet next step once the
  /// Ember is claimed on easy. Taking it counts as an explicit difficulty
  /// choice, so the title selector follows (same rule as a selector tap).
  void delveNormal() {
    final run = sim?.run;
    setPreferredDifficulty('normal');
    startRun(
      character: run?['character'] as String?,
      ascension: run?['ascension'] as int? ?? 0,
      boons: true,
      difficulty: 'normal',
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
    // v0.8.0 share trace: observed BEFORE _bankRun/_autosave so a terminal
    // command banks with its final floor mark and the save carries it.
    runTrace.observe(events);
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
      // v0.25.0: an outcome that changed nothing (a full-HP heal, a walk-away
      // option) used to resolve silently — the F5 promise is a CONCRETE
      // outcome for every choice, so state the neutral fact instead.
      flash = summary ?? 'Nothing changed';
      return;
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
        case 'face_tempered':
          flash =
              '${runeName(e['rune'] as String?)} tempered onto ${e['face']}';
          break;
        // v7 feedback rule: only announce what the numbers on screen do NOT
        // already say. Blade/Aegis and the assignment keystones are visible in
        // the die's own "+N SPENT"; these three are not.
        case 'reroll_gained':
          flash = 'Surge — a reroll returned';
          break;
        case 'echo_armed':
          flash = 'Echo armed — next ${e['other_action']} +1';
          break;
        case 'keystone_triggered':
          if (e['keystone'] == 'living_bastion') {
            flash = 'Living Bastion — ${e['amount']} block carried';
          }
          break;
        case 'keystone_taken':
          flash = '${keystoneDef(e['keystone'] as String).name} set';
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

  /// v0.10.0: the player dismissed the active contextual tip — persist it.
  /// When the LAST tip is dismissed the legacy tutorialSeen flag is set too,
  /// so older builds sharing a cloud save never replay their 4-card wall.
  void dismissTip() {
    if (tipDirector.dismiss()) meta.tutorialSeen = true;
    MetaStore.save(meta);
  }

  /// v0.3.1 F11: persist that the first-fight tutorial has been seen.
  void markTutorialSeen() {
    if (meta.tutorialSeen) return;
    meta.tutorialSeen = true;
    MetaStore.save(meta);
  }

  /// v0.8.0 Guided Delve: forward a player moment to the tour; stamp +
  /// persist when it finishes. While the tour is on screen the contextual
  /// tips stay quiet (same suppression rule as the manual how-to-play).
  void tourMoment(TourMoment m) {
    if (tour.onMoment(m)) _stampTour();
  }

  /// Tap-to-continue on an info beat.
  void tourAdvanceInfo() {
    if (tour.advanceInfo()) _stampTour();
  }

  /// SKIP: always available, stamps exactly like completion (§Ethics —
  /// a skipped tour never nags again).
  void tourSkip() {
    if (tour.skip()) _stampTour();
  }

  /// Settings → "How to play (guided tour)": replay on the next fight.
  void requestTourReplay() {
    tour = TourDirector(seenVersion: meta.tourSeenVersion, replay: true);
  }

  void _stampTour() {
    if (meta.tourSeenVersion < tourVersion) {
      meta.tourSeenVersion = tourVersion;
    }
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
    weeklyIndex = null;
    weeklyMutator = null;
    _bankedThisRun = false;
    _lastEnemyId = null;
    _restedThisRun = false;
    runFirstMet.clear();
    runFirstFelled.clear();
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
          if (id is String) {
            _lastEnemyId = id;
            // v0.11.0: per-enemy record — met. A lifetime 0 -> 1 is this
            // run's "first sighting".
            if ((meta.enemyMet[id] ?? 0) == 0) runFirstMet.add(id);
            meta.enemyMet[id] = (meta.enemyMet[id] ?? 0) + 1;
          }
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
      // v0.11.0: per-enemy record — it felled you. (A resumed mid-fight run
      // has no _lastEnemyId; same known gap as the boss ledger.)
      final id = _lastEnemyId;
      if (id != null) {
        meta.enemyFellTo[id] = (meta.enemyFellTo[id] ?? 0) + 1;
      }
    }
    if (!fightWon) return;
    // v0.11.0: per-enemy record — felled. A lifetime 0 -> 1 is this run's
    // "first felling".
    final felledId = _lastEnemyId;
    if (felledId != null) {
      if ((meta.enemyFelled[felledId] ?? 0) == 0) {
        runFirstFelled.add(felledId);
      }
      meta.enemyFelled[felledId] = (meta.enemyFelled[felledId] ?? 0) + 1;
    }
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
    // v0.13.0 Delver's Rank: rank is derived, so a rank-up is just the tier
    // before banking vs after. Snapshot BEFORE any counter moves.
    final rankBefore = rankFor(meta);
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
        final opened = (asc + 1).clamp(0, 20);
        // v0.32.0 (hook #7): announce the rung only when it actually moved —
        // a win at the rung-20 cap re-clamps to 20 and says nothing.
        if (opened > meta.bestAscension) pendingRungOpened = opened;
        meta.bestAscension = opened;
      }
    }
    // Daily Delve record (v0.3.4): only a FINISHED daily counts as played —
    // abandoning mid-run records nothing. One record, no history/streaks.
    if (dailyDate != null) {
      meta.lastDailyDate = dailyDate;
      meta.lastDailyWon = sim!.phase == 'run_won';
      meta.lastDailyFloor = floorReached;
      meta.lastDailyFloors = (sim!.map?['layers'] as int?) ?? 0;
      // v0.9.0 Today's Trials: a goal day's bonus banks here, once, through
      // the same guarded path as everything else (idempotent on resume — a
      // trial is a pure function of the date label, nothing new persists).
      // Missing the goal costs nothing and says nothing (§Ethics).
      final trial = trialForDailyKey(dailyDate!);
      if (trial != null &&
          trial.goalId.isNotEmpty &&
          trialGoalMet(trial, run, runTrace)) {
        meta.embers += trial.emberBonus;
        meta.lifetimeEmbers += trial.emberBonus;
      }
    }
    // Weekly Delve record (P3): same charter as the daily — only a FINISHED
    // weekly records anything, and it's one record with no history/streaks.
    if (weeklyIndex != null) {
      meta.lastWeeklyKey = weeklyKey(weeklyIndex!);
      meta.lastWeeklyWon = sim!.phase == 'run_won';
      meta.lastWeeklyFloor = floorReached;
      meta.lastWeeklyFloors = (sim!.map?['layers'] as int?) ?? 0;
      meta.lastWeeklyMutator = weeklyMutator ?? '';
      meta.weekliesPlayed += 1;
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
    // v0.13.0 Delver's Rank: announce a crossed tier once, in the same
    // breath as the result. Derived state — nothing persists for this.
    final rankAfter = rankFor(meta);
    if (rankAfter.marks > rankBefore.marks) pendingRankUp = rankAfter;
    // In-app review ask (REVENUE ASK #1): one quiet ask, ever, at a moment
    // of earned pride — 2nd+ win or a won daily/weekly, never while the
    // tour runs. Stamps meta.reviewAsked; the save below persists it.
    ReviewService.instance.maybeAsk(
      meta,
      wonThisRun: sim!.phase == 'run_won',
      wonDailyOrWeekly:
          sim!.phase == 'run_won' && (dailyDate != null || weeklyIndex != null),
      tourActive: tour.active != null,
    );
    MetaStore.save(meta);
    // P4/P5 (v0.5.0): mirror the fresh snapshot to the Play Games cloud save
    // and submit a finished Daily/Weekly Delve to its leaderboard. Both are
    // silent no-ops unless the player connected Play Games in Settings
    // (opt-in, §Ethics) — and never block or fail the bank itself.
    unawaited(PlayGamesService.instance.pushSnapshot(meta));
    unawaited(
      PlayGamesService.instance.submitRunScore(
        isDaily: dailyDate != null,
        isWeekly: weeklyIndex != null,
        embersBanked: banked,
      ),
    );
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

  /// The trial declared for this run's daily date; null for non-daily runs
  /// (v0.9.0). Re-derived from the persisted date label, so a resumed daily
  /// keeps its trial for free.
  TrialDef? get dailyTrial =>
      dailyDate == null ? null : trialForDailyKey(dailyDate!);

  /// Embers this finished daily earned from its trial goal; 0 mid-run, on
  /// mutator days, and when the goal was missed. Pure recomputation of the
  /// exact judgement _bankRun made, so the summary chip can never disagree
  /// with what was actually banked.
  int get dailyTrialBonus {
    final trial = dailyTrial;
    if (trial == null || trial.goalId.isEmpty) return 0;
    if (!_terminal.contains(sim?.phase) || sim?.phase == 'idle') return 0;
    final run = sim?.run;
    if (run == null) return 0;
    return trialGoalMet(trial, run, runTrace) ? trial.emberBonus : 0;
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
      grid: traceGrid(runTrace),
      trial: dailyTrial?.name ?? '',
    );
  }

  /// Copyable Weekly Delve result for the summary screen, or null when this
  /// run wasn't the weekly (or hasn't ended). Built from the banked meta
  /// record so it matches the title recap exactly (same charter as
  /// [dailyResultShareText]).
  String? get weeklyResultShareText {
    if (weeklyIndex == null) return null;
    if (meta.lastWeeklyKey != weeklyKey(weeklyIndex!)) return null;
    if (!_terminal.contains(sim?.phase) || sim?.phase == 'idle') return null;
    return weeklyShareText(
      index: weeklyIndex!,
      mutatorId: meta.lastWeeklyMutator,
      won: meta.lastWeeklyWon,
      floor: meta.lastWeeklyFloor,
      floors: meta.lastWeeklyFloors,
      grid: traceGrid(runTrace),
    );
  }

  /// Copyable seed challenge for a finished NORMAL/seeded run (v0.8.0).
  /// Daily/Weekly runs keep their own share text (their seed is implicit in
  /// the date/week); everything else gets "here is the exact delve I played".
  /// Null mid-run and on the title screen.
  String? get seedChallengeShareText {
    if (dailyDate != null || weeklyIndex != null) return null;
    final s = sim;
    if (s == null || !_terminal.contains(s.phase) || s.phase == 'idle') {
      return null;
    }
    final run = s.run;
    return seedChallengeText(
      seed: s.runSeed,
      difficulty: run?['difficulty'] as String? ?? 'normal',
      ascension: run?['ascension'] as int? ?? 0,
      won: s.phase == 'run_won',
      floor: floorReached,
      floors: s.map?['layers'] as int? ?? 0,
      grid: traceGrid(runTrace),
    );
  }

  /// Surface a toast from UI actions that don't go through the sim
  /// (e.g. "Result copied").
  void announce(String message) {
    flash = message;
    notifyListeners();
  }

  /// Adopt a cloud-merged meta snapshot (P4, see meta/cloud_merge.dart) as
  /// the live profile and persist it. Called by the Play Games sync after
  /// connect/resume — never mid-run banking (the merge inputs both came from
  /// banked state, so nothing here can double-count a run in progress).
  Future<void> adoptMeta(MetaState merged) async {
    meta = merged;
    notifyListeners();
    await MetaStore.save(meta);
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
    weeklyIndex = null;
    weeklyMutator = null;
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
