// core/save.dart — save schema v2 + atomic persistence.
// Pattern kept from v1: write .tmp → rename over live file → refresh .bak.
// Field-tolerant reads (every field has a default). Base directory is
// injectable so tests never touch path_provider.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int saveSchemaVersion = 2;
const String _fileName = 'emberdelve_save.json';

class LevelRecord {
  bool finished;
  bool allChests;
  bool lowDamage; // took <= 1 hit
  int chestsOpened;
  int secretsFound;
  int bestTimeMs; // 0 = none

  LevelRecord({
    this.finished = false,
    this.allChests = false,
    this.lowDamage = false,
    this.chestsOpened = 0,
    this.secretsFound = 0,
    this.bestTimeMs = 0,
  });

  int get medals => (finished ? 1 : 0) + (allChests ? 1 : 0) + (lowDamage ? 1 : 0);

  Map<String, Object> toJson() => {
        'finished': finished,
        'allChests': allChests,
        'lowDamage': lowDamage,
        'chestsOpened': chestsOpened,
        'secretsFound': secretsFound,
        'bestTimeMs': bestTimeMs,
      };

  factory LevelRecord.fromJson(Map<String, dynamic> j) => LevelRecord(
        finished: j['finished'] as bool? ?? false,
        allChests: j['allChests'] as bool? ?? false,
        lowDamage: j['lowDamage'] as bool? ?? false,
        chestsOpened: (j['chestsOpened'] as num?)?.toInt() ?? 0,
        secretsFound: (j['secretsFound'] as num?)?.toInt() ?? 0,
        bestTimeMs: (j['bestTimeMs'] as num?)?.toInt() ?? 0,
      );
}

class SaveData {
  int coins;
  int feathers;
  Set<String> ownedWeapons;
  String equippedWeapon;
  Set<String> ownedSkins;
  Map<String, int> skinKills; // skin id -> lifetime kills (drives skin level)
  String equippedSkin;
  Set<String> ownedAbilities;
  Set<String> ownedSpells; // AKP-4d spell slot (owner-confirmed 2026-07-25)
  String equippedSpell; // '' = no spell equipped
  Map<String, LevelRecord> levels; // level id (e.g. 'w1_l1') -> record
  bool tutorialSeen;
  bool legacyBonusGranted; // one-time coin gift for v1 dice-save owners
  String dailyBestDate; // dailyKey of the recorded daily best ('' = none)
  int dailyBestTimeMs; // best Daily Delve time for dailyBestDate (0 = none)

  SaveData({
    this.coins = 0,
    this.feathers = 0,
    Set<String>? ownedWeapons,
    this.equippedWeapon = 'squire_blade',
    Set<String>? ownedSkins,
    Map<String, int>? skinKills,
    this.equippedSkin = 'red',
    Set<String>? ownedAbilities,
    Set<String>? ownedSpells,
    this.equippedSpell = '',
    Map<String, LevelRecord>? levels,
    this.tutorialSeen = false,
    this.legacyBonusGranted = false,
    this.dailyBestDate = '',
    this.dailyBestTimeMs = 0,
  })  : ownedWeapons = ownedWeapons ?? {'squire_blade'},
        ownedSkins = ownedSkins ?? {'red'},
        skinKills = skinKills ?? {},
        ownedAbilities = ownedAbilities ?? {},
        ownedSpells = ownedSpells ?? {},
        levels = levels ?? {};

  LevelRecord recordFor(String levelId) =>
      levels.putIfAbsent(levelId, LevelRecord.new);

  Map<String, Object> toJson() => {
        'version': saveSchemaVersion,
        'coins': coins,
        'feathers': feathers,
        'ownedWeapons': ownedWeapons.toList(),
        'equippedWeapon': equippedWeapon,
        'ownedSkins': ownedSkins.toList(),
        'skinKills': skinKills,
        'equippedSkin': equippedSkin,
        'ownedAbilities': ownedAbilities.toList(),
        'ownedSpells': ownedSpells.toList(),
        'equippedSpell': equippedSpell,
        'levels': levels.map((k, v) => MapEntry(k, v.toJson())),
        'tutorialSeen': tutorialSeen,
        'legacyBonusGranted': legacyBonusGranted,
        'dailyBestDate': dailyBestDate,
        'dailyBestTimeMs': dailyBestTimeMs,
      };

  factory SaveData.fromJson(Map<String, dynamic> j) {
    final version = (j['version'] as num?)?.toInt() ?? 1;
    if (version < 2) {
      // v1 = dice-era save. Nothing carries over mechanically; grant a small
      // thank-you bonus to returning testers exactly once.
      return SaveData(coins: 250, legacyBonusGranted: true);
    }
    return SaveData(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      feathers: (j['feathers'] as num?)?.toInt() ?? 0,
      ownedWeapons: ((j['ownedWeapons'] as List?)?.cast<String>() ??
              ['squire_blade'])
          .toSet(),
      equippedWeapon: j['equippedWeapon'] as String? ?? 'squire_blade',
      ownedSkins: ((j['ownedSkins'] as List?)?.cast<String>() ?? ['red']).toSet(),
      skinKills: (j['skinKills'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
          {},
      equippedSkin: j['equippedSkin'] as String? ?? 'red',
      ownedAbilities:
          ((j['ownedAbilities'] as List?)?.cast<String>() ?? []).toSet(),
      ownedSpells:
          ((j['ownedSpells'] as List?)?.cast<String>() ?? []).toSet(),
      equippedSpell: j['equippedSpell'] as String? ?? '',
      levels: (j['levels'] as Map?)?.map((k, v) => MapEntry(
              k as String,
              LevelRecord.fromJson((v as Map).cast<String, dynamic>()))) ??
          {},
      tutorialSeen: j['tutorialSeen'] as bool? ?? false,
      legacyBonusGranted: j['legacyBonusGranted'] as bool? ?? false,
      dailyBestDate: j['dailyBestDate'] as String? ?? '',
      dailyBestTimeMs: (j['dailyBestTimeMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class SaveStore {
  /// Injectable for tests; defaults to app documents dir at first use.
  final Directory? baseDirOverride;
  SaveStore({this.baseDirOverride});

  Future<Directory> _dir() async =>
      baseDirOverride ?? await getApplicationDocumentsDirectory();

  Future<File> _file() async => File('${(await _dir()).path}/$_fileName');
  Future<File> _bak() async => File('${(await _dir()).path}/$_fileName.bak');
  Future<File> _tmp() async => File('${(await _dir()).path}/$_fileName.tmp');

  Future<SaveData> load() async {
    for (final f in [await _file(), await _bak()]) {
      try {
        if (!await f.exists()) continue;
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return SaveData.fromJson(j);
      } catch (_) {
        // Corrupt file → try backup; corrupt backup → fresh save.
      }
    }
    return SaveData();
  }

  Future<void> save(SaveData data) async {
    final live = await _file();
    final tmp = await _tmp();
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (await live.exists()) {
      try {
        await live.copy((await _bak()).path);
      } catch (_) {}
    }
    await tmp.rename(live.path);
  }
}
