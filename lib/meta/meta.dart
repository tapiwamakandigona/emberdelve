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

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<MetaState> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return MetaState();
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return MetaState.fromJson(data);
    } catch (_) {
      return MetaState();
    }
  }

  static Future<void> save(MetaState state) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {/* best-effort; never crash the game on save failure */}
  }
}
