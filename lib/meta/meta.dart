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
import '../data/themes.dart';

/// Schema version stamped into emberdelve_meta.json (v0.3.4).
/// v1 = every file written before the field existed (absence ⇒ 1). Readers
/// stay field-tolerant — every field has a default — so bumping this is only
/// needed when a MIGRATION must run, not when fields are merely added.
const int metaSchemaVersion = 2;

class MetaState {
  int embers;
  Set<String> unlockedCharacters;
  int bestAscension;
  int runsPlayed;
  int runsWon;
  bool tutorialSeen; // v0.3.1 F11: first-fight overlay shown once, ever
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
  MetaState({
    this.embers = 0,
    Set<String>? unlocked,
    this.bestAscension = 0,
    this.runsPlayed = 0,
    this.runsWon = 0,
    this.tutorialSeen = false,
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
  })  : unlockedCharacters = unlocked ?? {defaultCharacter},
        charRuns = charRuns ?? {},
        charWins = charWins ?? {},
        ownedThemes = ownedThemes ?? {defaultTheme};

  Map<String, Object?> toJson() => {
        'schema': metaSchemaVersion,
        'embers': embers,
        'unlocked': unlockedCharacters.toList(),
        'bestAscension': bestAscension,
        'runsPlayed': runsPlayed,
        'runsWon': runsWon,
        'tutorialSeen': tutorialSeen,
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
      };

  static Map<String, int> _intMap(Object? v) =>
      (v as Map?)?.map((k, n) => MapEntry('$k', (n as num).toInt())) ?? {};

  factory MetaState.fromJson(Map<String, dynamic> j) => MetaState(
        embers: j['embers'] as int? ?? 0,
        unlocked: ((j['unlocked'] as List?)?.cast<String>().toSet()) ??
            {defaultCharacter},
        bestAscension: j['bestAscension'] as int? ?? 0,
        runsPlayed: j['runsPlayed'] as int? ?? 0,
        runsWon: j['runsWon'] as int? ?? 0,
        tutorialSeen: j['tutorialSeen'] as bool? ?? false,
        preferredDifficulty: const {'easy', 'normal', 'hard'}
                .contains(j['preferredDifficulty'])
            ? j['preferredDifficulty'] as String
            : 'normal',
        // Pre-v0.3.3 saves lack the flag; a veteran profile (runs played)
        // must never be steered, so treat it as already chosen.
        difficultyChosen: j['difficultyChosen'] as bool? ??
            ((j['runsPlayed'] as int? ?? 0) > 0),
        charRuns: _intMap(j['charRuns']),
        charWins: _intMap(j['charWins']),
        lifetimeEmbers: j['lifetimeEmbers'] as int? ?? 0,
        exactKills: j['exactKills'] as int? ?? 0,
        exactStreak: j['exactStreak'] as int? ?? 0,
        bestExactStreak: j['bestExactStreak'] as int? ?? 0,
        ownedThemes: ((j['ownedThemes'] as List?)?.cast<String>().toSet()
              ?..add(defaultTheme)) ??
            {defaultTheme},
        activeTheme: hearthThemes.containsKey(j['activeTheme'])
            ? j['activeTheme'] as String
            : defaultTheme,
      );

  /// First-run on-ramp (v0.3.3): a brand-new profile that has never touched
  /// the selector is steered toward easy — visibly, on the selector itself,
  /// with an honest "recommended" caption. One explicit tap ends it forever.
  bool get steerToEasy => !difficultyChosen && runsPlayed == 0;
  String get effectiveDifficulty =>
      steerToEasy ? 'easy' : preferredDifficulty;

  /// Try to buy a hearth theme with embers; returns true on success.
  bool tryBuyTheme(String id) {
    final t = hearthThemes[id];
    if (t == null || ownedThemes.contains(id)) return false;
    if (embers < t.costEmbers) return false;
    embers -= t.costEmbers;
    ownedThemes.add(id);
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
    } catch (_) {/* fall through to a fresh profile */}
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
      } catch (_) {/* best-effort */}
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
      } catch (_) {/* best-effort; never crash the game on save failure */}
    });
    return _writeQueue;
  }
}
