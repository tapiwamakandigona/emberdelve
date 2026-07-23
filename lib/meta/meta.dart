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

class MetaState {
  int embers;
  Set<String> unlockedCharacters;
  int bestAscension;
  int runsPlayed;
  int runsWon;
  bool tutorialSeen; // v0.3.1 F11: first-fight overlay shown once, ever
  MetaState({
    this.embers = 0,
    Set<String>? unlocked,
    this.bestAscension = 0,
    this.runsPlayed = 0,
    this.runsWon = 0,
    this.tutorialSeen = false,
  }) : unlockedCharacters = unlocked ?? {defaultCharacter};

  Map<String, Object?> toJson() => {
        'embers': embers,
        'unlocked': unlockedCharacters.toList(),
        'bestAscension': bestAscension,
        'runsPlayed': runsPlayed,
        'runsWon': runsWon,
        'tutorialSeen': tutorialSeen,
      };

  factory MetaState.fromJson(Map<String, dynamic> j) => MetaState(
        embers: j['embers'] as int? ?? 0,
        unlocked: ((j['unlocked'] as List?)?.cast<String>().toSet()) ??
            {defaultCharacter},
        bestAscension: j['bestAscension'] as int? ?? 0,
        runsPlayed: j['runsPlayed'] as int? ?? 0,
        runsWon: j['runsWon'] as int? ?? 0,
        tutorialSeen: j['tutorialSeen'] as bool? ?? false,
      );

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
