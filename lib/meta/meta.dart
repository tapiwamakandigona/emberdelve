// lib/meta/meta.dart — meta-progression state (OUTSIDE the deterministic sim).
// Persists embers, unlocked characters, best ascension, and lifetime stats via
// path_provider. The only values it ever feeds the sim are the two scalar
// start_run params (character id + ascension) — see docs/m3-contract.md §8.
//
// Endowed-progress (UXPeak goal-gradient, applied honestly): the next-unlock
// bar shows REAL earned progress toward the cheapest locked character; it is
// never faked and never starts at a lie.
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/characters.dart';
import '../game/tips.dart' show ContextTips;
import '../data/codex.dart';
import '../data/skins.dart';
import '../data/themes.dart';

/// Schema version stamped into emberdelve_meta.json (v0.3.4).
/// v1 = every file written before the field existed (absence ⇒ 1). Readers
/// stay field-tolerant — every field has a default — so bumping this is only
/// needed when a MIGRATION must run, not when fields are merely added.
const int metaSchemaVersion = 3;

class MetaState {
  int embers;
  Set<String> unlockedCharacters;
  int bestAscension;
  int runsPlayed;
  int runsWon;
  bool tutorialSeen; // v0.3.1 F11: first-fight overlay shown once, ever
  // v0.10.0 The First Delve: contextual tips already dismissed (ids from
  // ContextTips.all). Sticky like tutorialSeen — cloud merge is set union.
  Set<String> tipsSeen;
  // v0.8.0 The Guided Delve: highest anchored-tour version this profile has
  // completed or skipped (tour.dart/tourVersion). 0 = never toured — new
  // installs AND veterans of the old card wall both see tour v2 once.
  int tourSeenVersion;
  // v0.3.2: sticky easy/normal/hard preference for the title-screen selector.
  // Pure convenience — the sim only ever sees it as a start_run param.
  String preferredDifficulty;
  // v0.3.3: true once the player has TAPPED the selector at least once.
  // While false and runsPlayed == 0, the title steers a brand-new profile
  // toward easy (first-run on-ramp) — never silently after that.
  bool difficultyChosen;
  // v0.3.3 ledger stats — all real, never faked (§Ethics honesty):
  // per-character runs/wins, lifetime embers banked, exact-kill counters.
  Map<String, int> charRuns;
  Map<String, int> charWins;
  int lifetimeEmbers;
  int exactKills;
  int exactStreak; // current consecutive fights ended with an exact kill
  int bestExactStreak;
  // v0.3.3 hearth colors — ember-priced cosmetic tints for the title hearth.
  // Pure ember sink after all delvers unlock; no gameplay effect, no FOMO.
  Set<String> ownedThemes;
  String activeTheme;
  // v0.4.3 P1 ember sink — dice skins + Codex. Same charter as hearth
  // colors: pure cosmetics / lore, ember-priced, never a gameplay effect.
  Set<String> ownedDieSkins;
  String activeDieSkin;
  Set<String> ownedCodex; // namespaced ids: 'enemy:<id>' / 'relic:<id>'
  // v0.3.4 Daily Delve record (review note #3): remember the most recent
  // daily played so the title shows an honest recap and the summary offers a
  // copyable result. ONE record — deliberately no daily history, no streaks,
  // no expiry pressure (§Ethics).
  String? lastDailyDate; // local 'YYYY-MM-DD' the daily was finished
  bool lastDailyWon;
  int lastDailyFloor; // 1-based layer reached (boss layer when won)
  int lastDailyFloors; // total layers on that day's map
  // P3 Weekly Delve record — same one-record, no-streaks, no-expiry charter
  // as the daily above (spec §Ethics). Remembers only the most recent week
  // finished so the title shows an honest recap and the summary a copyable
  // result. `lastWeeklyKey` is the weekly.dart key ('Week of YYYY-MM-DD');
  // `lastWeeklyMutator` is the modifier id that week ran under.
  String? lastWeeklyKey;
  bool lastWeeklyWon;
  int lastWeeklyFloor;
  int lastWeeklyFloors;
  String lastWeeklyMutator;
  int weekliesPlayed; // Weekly Delves FINISHED (abandoning counts for nothing)
  // v0.3.4 run history (review note #4): one small record per ENDED run
  // (won/lost/abandoned), newest first, capped — enough for a ledger page
  // and per-run seed replay, small enough to never bloat the save.
  // Record keys: date, character, difficulty, ascension, result, floor,
  // floors, seed, embers, daily(optional true).
  List<Map<String, Object?>> runHistory;
  static const int runHistoryCap = 30;
  // v0.4.0 Ember Forge (spec R8): true once the one-time full unlock has been
  // purchased (or restored) through Play Billing. Deliberately sticky: once
  // granted it is never revoked locally — an offline session or a transient
  // store error must never take paid content away (§Ethics: no punishment).
  // The source of truth for *granting* is always a Play purchase event
  // (see meta/store_service.dart), never this file alone.
  bool forgeUnlocked;
  // v0.5.0 Delver's Ledger (see data/achievements.dart). Five real counters
  // that the ledger reads, plus the set of achievements already announced so a
  // toast fires once and never again. Every counter here is banked at run end
  // in GameController._bankRun — none of them is derived or estimated, because
  // a progress bar built on a guess would be a lie (§Ethics honesty).
  Set<String> bossesBeaten; // distinct boss enemy ids put down on layer N
  Set<String> seenAchievements; // ids whose earned-toast has been shown
  int bestFloor; // deepest 1-based layer ever reached, won or lost
  int dailiesPlayed; // Daily Delves FINISHED (abandoning counts for nothing)
  int winsNoRest; // runs won without visiting a single rest node
  int hardWins; // runs won on hard
  // v0.11.0 Delver's Ledger — per-enemy record, keyed by enemy id. All
  // event-derived in GameController.recordCombatStats, never estimated.
  // Cloud merge: per-key MAX (same convention as charRuns/charWins).
  Map<String, int> enemyMet; // encounters started against this enemy
  Map<String, int> enemyFelled; // fights won against it
  Map<String, int> enemyFellTo; // fights it won against you
  // v0.15.0 Hearthside Post: the newest version whose title-screen note the
  // player has dismissed ('' = never). Cloud merge keeps the LARGER version
  // (compareVersions) so a merge can never re-show old news.
  String lastSeenNewsVersion;
  MetaState({
    this.embers = 0,
    Set<String>? unlocked,
    this.bestAscension = 0,
    this.runsPlayed = 0,
    this.runsWon = 0,
    this.tutorialSeen = false,
    Set<String>? tipsSeen,
    this.tourSeenVersion = 0,
    this.preferredDifficulty = 'normal',
    this.difficultyChosen = false,
    Map<String, int>? charRuns,
    Map<String, int>? charWins,
    this.lifetimeEmbers = 0,
    this.exactKills = 0,
    this.exactStreak = 0,
    this.bestExactStreak = 0,
    Set<String>? ownedThemes,
    this.activeTheme = defaultTheme,
    Set<String>? ownedDieSkins,
    this.activeDieSkin = defaultDieSkin,
    Set<String>? ownedCodex,
    this.lastDailyDate,
    this.lastDailyWon = false,
    this.lastDailyFloor = 0,
    this.lastDailyFloors = 0,
    this.lastWeeklyKey,
    this.lastWeeklyWon = false,
    this.lastWeeklyFloor = 0,
    this.lastWeeklyFloors = 0,
    this.lastWeeklyMutator = '',
    this.weekliesPlayed = 0,
    List<Map<String, Object?>>? runHistory,
    this.forgeUnlocked = false,
    Set<String>? bossesBeaten,
    Set<String>? seenAchievements,
    this.bestFloor = 0,
    this.dailiesPlayed = 0,
    this.winsNoRest = 0,
    this.hardWins = 0,
    Map<String, int>? enemyMet,
    Map<String, int>? enemyFelled,
    Map<String, int>? enemyFellTo,
    this.lastSeenNewsVersion = '',
  }) : runHistory = runHistory ?? [],
       bossesBeaten = bossesBeaten ?? {},
       seenAchievements = seenAchievements ?? {},
       unlockedCharacters = unlocked ?? {defaultCharacter},
       charRuns = charRuns ?? {},
       charWins = charWins ?? {},
       ownedThemes = ownedThemes ?? {defaultTheme},
       ownedDieSkins = ownedDieSkins ?? {defaultDieSkin},
       ownedCodex = ownedCodex ?? {},
       tipsSeen = tipsSeen ?? {},
       enemyMet = enemyMet ?? {},
       enemyFelled = enemyFelled ?? {},
       enemyFellTo = enemyFellTo ?? {};

  Map<String, Object?> toJson() => {
    'schema': metaSchemaVersion,
    'embers': embers,
    'unlocked': unlockedCharacters.toList(),
    'bestAscension': bestAscension,
    'runsPlayed': runsPlayed,
    'runsWon': runsWon,
    'tutorialSeen': tutorialSeen,
    if (tipsSeen.isNotEmpty) 'tipsSeen': (tipsSeen.toList()..sort()),
    if (tourSeenVersion != 0) 'tourSeenVersion': tourSeenVersion,
    'preferredDifficulty': preferredDifficulty,
    'difficultyChosen': difficultyChosen,
    'charRuns': charRuns,
    'charWins': charWins,
    'lifetimeEmbers': lifetimeEmbers,
    'exactKills': exactKills,
    'exactStreak': exactStreak,
    'bestExactStreak': bestExactStreak,
    'ownedThemes': ownedThemes.toList(),
    'activeTheme': activeTheme,
    'ownedDieSkins': ownedDieSkins.toList(),
    'activeDieSkin': activeDieSkin,
    if (ownedCodex.isNotEmpty) 'ownedCodex': ownedCodex.toList(),
    if (lastDailyDate != null) 'lastDailyDate': lastDailyDate,
    if (lastDailyDate != null) 'lastDailyWon': lastDailyWon,
    if (lastDailyDate != null) 'lastDailyFloor': lastDailyFloor,
    if (lastDailyDate != null) 'lastDailyFloors': lastDailyFloors,
    if (lastWeeklyKey != null) 'lastWeeklyKey': lastWeeklyKey,
    if (lastWeeklyKey != null) 'lastWeeklyWon': lastWeeklyWon,
    if (lastWeeklyKey != null) 'lastWeeklyFloor': lastWeeklyFloor,
    if (lastWeeklyKey != null) 'lastWeeklyFloors': lastWeeklyFloors,
    if (lastWeeklyKey != null) 'lastWeeklyMutator': lastWeeklyMutator,
    if (weekliesPlayed > 0) 'weekliesPlayed': weekliesPlayed,
    if (runHistory.isNotEmpty) 'runHistory': runHistory,
    if (forgeUnlocked) 'forgeUnlocked': true,
    if (bossesBeaten.isNotEmpty) 'bossesBeaten': bossesBeaten.toList(),
    if (seenAchievements.isNotEmpty)
      'seenAchievements': seenAchievements.toList(),
    if (bestFloor > 0) 'bestFloor': bestFloor,
    if (dailiesPlayed > 0) 'dailiesPlayed': dailiesPlayed,
    if (winsNoRest > 0) 'winsNoRest': winsNoRest,
    if (hardWins > 0) 'hardWins': hardWins,
    if (enemyMet.isNotEmpty) 'enemyMet': enemyMet,
    if (enemyFelled.isNotEmpty) 'enemyFelled': enemyFelled,
    if (enemyFellTo.isNotEmpty) 'enemyFellTo': enemyFellTo,
    if (lastSeenNewsVersion.isNotEmpty)
      'lastSeenNewsVersion': lastSeenNewsVersion,
  };

  /// Prepend a run record and trim to [runHistoryCap] (newest first).
  void addRunRecord(Map<String, Object?> record) {
    runHistory.insert(0, record);
    if (runHistory.length > runHistoryCap) {
      runHistory.removeRange(runHistoryCap, runHistory.length);
    }
  }

  static Map<String, int> _intMap(Object? v) =>
      (v as Map?)?.map((k, n) => MapEntry('$k', (n as num).toInt())) ?? {};

  factory MetaState.fromJson(Map<String, dynamic> j) => MetaState(
    embers: j['embers'] as int? ?? 0,
    unlocked:
        ((j['unlocked'] as List?)?.cast<String>().toSet()) ??
        {defaultCharacter},
    bestAscension: j['bestAscension'] as int? ?? 0,
    runsPlayed: j['runsPlayed'] as int? ?? 0,
    runsWon: j['runsWon'] as int? ?? 0,
    tutorialSeen: j['tutorialSeen'] as bool? ?? false,
    // v0.10.0 migration: a save that finished the old 4-card wall but has no
    // tipsSeen key is a veteran — pre-seed all tips so nothing replays.
    tipsSeen:
        ((j['tipsSeen'] as List?)?.cast<String>().toSet()) ??
        ((j['tutorialSeen'] as bool? ?? false)
            ? ContextTips.all.toSet()
            : <String>{}),
    tourSeenVersion: j['tourSeenVersion'] as int? ?? 0,
    preferredDifficulty:
        const {'easy', 'normal', 'hard'}.contains(j['preferredDifficulty'])
        ? j['preferredDifficulty'] as String
        : 'normal',
    // Pre-v0.3.3 saves lack the flag; a veteran profile (runs played)
    // must never be steered, so treat it as already chosen.
    difficultyChosen:
        j['difficultyChosen'] as bool? ?? ((j['runsPlayed'] as int? ?? 0) > 0),
    charRuns: _intMap(j['charRuns']),
    charWins: _intMap(j['charWins']),
    lifetimeEmbers: j['lifetimeEmbers'] as int? ?? 0,
    exactKills: j['exactKills'] as int? ?? 0,
    exactStreak: j['exactStreak'] as int? ?? 0,
    bestExactStreak: j['bestExactStreak'] as int? ?? 0,
    ownedThemes:
        ((j['ownedThemes'] as List?)?.cast<String>().toSet()
          ?..add(defaultTheme)) ??
        {defaultTheme},
    activeTheme: hearthThemes.containsKey(j['activeTheme'])
        ? j['activeTheme'] as String
        : defaultTheme,
    ownedDieSkins:
        ((j['ownedDieSkins'] as List?)?.cast<String>().toSet()
          ?..add(defaultDieSkin)) ??
        {defaultDieSkin},
    activeDieSkin: dieSkins.containsKey(j['activeDieSkin'])
        ? j['activeDieSkin'] as String
        : defaultDieSkin,
    ownedCodex: ((j['ownedCodex'] as List?)?.cast<String>().toSet()) ?? {},
    lastDailyDate: j['lastDailyDate'] as String?,
    lastDailyWon: j['lastDailyWon'] as bool? ?? false,
    lastDailyFloor: j['lastDailyFloor'] as int? ?? 0,
    lastDailyFloors: j['lastDailyFloors'] as int? ?? 0,
    lastWeeklyKey: j['lastWeeklyKey'] as String?,
    lastWeeklyWon: j['lastWeeklyWon'] as bool? ?? false,
    lastWeeklyFloor: j['lastWeeklyFloor'] as int? ?? 0,
    lastWeeklyFloors: j['lastWeeklyFloors'] as int? ?? 0,
    lastWeeklyMutator: j['lastWeeklyMutator'] as String? ?? '',
    weekliesPlayed: j['weekliesPlayed'] as int? ?? 0,
    runHistory: ((j['runHistory'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => r.map((k, v) => MapEntry('$k', v as Object?)))
        .toList(),
    forgeUnlocked: j['forgeUnlocked'] as bool? ?? false,
    bossesBeaten: ((j['bossesBeaten'] as List?)?.cast<String>().toSet()) ?? {},
    seenAchievements:
        ((j['seenAchievements'] as List?)?.cast<String>().toSet()) ?? {},
    // Pre-v0.5.0 saves have no bestFloor. Seeding it from the run history
    // (the deepest floor we can actually prove) is honest; inventing a
    // number from runsPlayed would not be.
    bestFloor:
        j['bestFloor'] as int? ??
        _deepestFloorIn((j['runHistory'] as List?) ?? const []),
    dailiesPlayed:
        j['dailiesPlayed'] as int? ??
        // A pre-v0.5.0 profile with a recorded daily has provably finished
        // at least one; anything beyond that is unknowable, so claim one.
        ((j['lastDailyDate'] is String) ? 1 : 0),
    winsNoRest: j['winsNoRest'] as int? ?? 0,
    hardWins: j['hardWins'] as int? ?? 0,
    enemyMet: _intMap(j['enemyMet']),
    enemyFelled: _intMap(j['enemyFelled']),
    enemyFellTo: _intMap(j['enemyFellTo']),
    lastSeenNewsVersion: j['lastSeenNewsVersion'] as String? ?? '',
  );

  /// Deepest `floor` value in a raw runHistory list; 0 when unknown. Used only
  /// to migrate pre-v0.5.0 saves (see [fromJson]).
  static int _deepestFloorIn(List raw) {
    var best = 0;
    for (final r in raw) {
      if (r is! Map) continue;
      final f = r['floor'];
      if (f is int && f > best) best = f;
    }
    return best;
  }

  /// First-run on-ramp (v0.3.3): a brand-new profile that has never touched
  /// the selector is steered toward easy — visibly, on the selector itself,
  /// with an honest "recommended" caption. One explicit tap ends it forever.
  bool get steerToEasy => !difficultyChosen && runsPlayed == 0;
  String get effectiveDifficulty => steerToEasy ? 'easy' : preferredDifficulty;

  /// Try to buy a hearth theme with embers; returns true on success.
  bool tryBuyTheme(String id) {
    final t = hearthThemes[id];
    if (t == null || ownedThemes.contains(id)) return false;
    if (embers < t.costEmbers) return false;
    embers -= t.costEmbers;
    ownedThemes.add(id);
    return true;
  }

  /// Try to buy a dice skin with embers; returns true on success.
  bool tryBuyDieSkin(String id) {
    final s = dieSkins[id];
    if (s == null || ownedDieSkins.contains(id)) return false;
    if (embers < s.costEmbers) return false;
    embers -= s.costEmbers;
    ownedDieSkins.add(id);
    return true;
  }

  /// Try to buy a Codex entry with embers; returns true on success.
  bool tryBuyCodex(String id) {
    final e = codexById[id];
    if (e == null || ownedCodex.contains(id)) return false;
    if (embers < e.costEmbers) return false;
    embers -= e.costEmbers;
    ownedCodex.add(id);
    return true;
  }

  bool isUnlocked(String characterId) =>
      unlockedCharacters.contains(characterId) ||
      characterId == defaultCharacter;

  /// The cheapest still-locked character, or null if all unlocked.
  CharacterDef? get nextUnlockTarget {
    CharacterDef? best;
    for (final id in charactersOrder) {
      if (isUnlocked(id)) continue;
      final c = characters[id]!;
      if (best == null || c.unlockEmbers < best.unlockEmbers) best = c;
    }
    return best;
  }

  /// Try to unlock a character by spending embers; returns true on success.
  bool tryUnlock(String characterId) {
    final c = characters[characterId];
    if (c == null || isUnlocked(characterId)) return false;
    if (embers < c.unlockEmbers) return false;
    embers -= c.unlockEmbers;
    unlockedCharacters.add(characterId);
    return true;
  }
}

class MetaStore {
  static const _fileName = 'emberdelve_meta.json';

  /// Test seam, mirroring GameController.saveDirOverride: when set, meta
  /// persistence targets this directory instead of path_provider.
  static String? dirOverride;

  static Future<File> _file() async {
    if (dirOverride != null) return File('$dirOverride/$_fileName');
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Parse one candidate save file; null when missing/unreadable/corrupt.
  static Future<MetaState?> _loadFrom(File f) async {
    try {
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return MetaState.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Load with backup fallback (v0.3.4): a corrupt/missing main file no
  /// longer silently resets all progress — the previous good save is kept as
  /// `.bak` by [save] and restored from here. Only when BOTH copies are
  /// unreadable does the player get a fresh profile.
  static Future<MetaState> load() async {
    try {
      final f = await _file();
      final main = await _loadFrom(f);
      if (main != null) return main;
      final fromBak = await _loadFrom(File('${f.path}.bak'));
      if (fromBak != null) {
        // Heal the main file so the recovery survives even if the game
        // exits before the next natural save. Deliberately NOT a normal
        // save(): that would demote the corrupt main file over the .bak we
        // just recovered from — the one good copy must stay untouched
        // until a complete main file is back in place.
        await _healMain(jsonEncode(fromBak.toJson()));
        return fromBak;
      }
    } catch (_) {
      /* fall through to a fresh profile */
    }
    return MetaState();
  }

  /// Same durability contract as the run autosave (see GameController's
  /// `_saveQueue`, PR #2): the JSON snapshot is captured synchronously at
  /// call time, writes are chained on a queue so rapid saves (bank + unlock
  /// + theme buy) can't interleave bytes, and each write goes to a temp file
  /// that is renamed into place so a crash mid-write can never leave a
  /// truncated meta file — this file holds embers/unlocks/lifetime stats,
  /// the one save whose loss is unrecoverable.
  static Future<void> _writeQueue = Future.value();

  /// Recovery-only write: atomically replace the main file WITHOUT touching
  /// `.bak` (see [load]). Rides the same queue as [save] so it can never
  /// interleave with a normal write.
  static Future<void> _healMain(String snap) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(snap, flush: true);
        await tmp.rename(f.path);
      } catch (_) {
        /* best-effort */
      }
    });
    return _writeQueue;
  }

  static Future<void> save(MetaState state) {
    final snap = jsonEncode(state.toJson());
    _writeQueue = _writeQueue.then((_) async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(snap, flush: true);
        // Two-generation scheme (v0.3.4): demote the current save to `.bak`
        // BEFORE promoting the new bytes. Both steps are atomic renames, so
        // at every instant at least one of {main, bak} is a complete save:
        //   crash after demote  -> main missing, bak = last good (load heals)
        //   crash after promote -> main = new,   bak = previous good
        if (await f.exists()) await f.rename('${f.path}.bak');
        await tmp.rename(f.path);
      } catch (_) {
        /* best-effort; never crash the game on save failure */
      }
    });
    return _writeQueue;
  }
}
