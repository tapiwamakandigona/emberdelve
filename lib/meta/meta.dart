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
import '../data/enemies.dart';
import '../game/tips.dart' show ContextTips;
import '../data/codex.dart';
import '../data/attire.dart';
import '../data/vistas.dart';
import '../data/epithets.dart';
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
  // v0.49.0 The Shorter Road: sticky Short Delve (6-layer) format toggle.
  // Pure convenience like preferredDifficulty — the sim only ever sees it
  // as the `short_road` mutator id on start_run.
  bool preferShortRoad;
  // v0.3.3 ledger stats — all real, never faked (§Ethics honesty):
  // per-character runs/wins, lifetime embers banked, exact-kill counters.
  Map<String, int> charRuns;
  Map<String, int> charWins;
  // v0.123.0 The Crowned Company: hard-mode wins charted per delver — the
  // same honesty contract as charWins (real counters, banked at run end,
  // cloud merge per-key MAX). Empty until a hard win; absent key = 0.
  Map<String, int> charHardWins;
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
  // v0.27.0 The Delver's Wardrobe — delver dyes (first outside player ask).
  // Same charter as themes/skins: pure cosmetic, ember-priced, no FOMO.
  Set<String> ownedDyes;
  String activeDye;
  // v0.35.0 The Vistas — selected background grade. Milestone-derived
  // unlocks (data/vistas.dart), so only the SELECTION persists.
  String selectedVista;
  // v0.36.0 The Epithets — worn title ('' = none). Milestone-derived
  // unlocks (data/epithets.dart via the Ledger's statValue), so only the
  // SELECTION persists.
  String selectedEpithet;
  // v0.66.0 The Dressed Delver — per-delver worn title (delver id →
  // epithet id). An absent key falls back to the legacy global selection,
  // so a pre-v0.66.0 choice keeps being honored on every delver until the
  // player dresses that delver differently. selectedEpithet is never
  // written after v0.66.0; it survives purely as this fallback.
  Map<String, String> charEpithet;

  /// v0.72.0: the name a given delver was GIVEN by the player — their own
  /// when they have one, else the delver's true name from the roster.
  /// Same contract as charEpithet/charDye: absent key = default; the
  /// built-in name is never overwritten.
  Map<String, String> charName;

  /// v0.75.0 The Hearth Song: a heard Gramophone track pinned as the
  /// hearth's music. '' = the default Hearthside. HONESTY at read time:
  /// resolvers fall back to the default whenever this key is unheard or
  /// unknown, so a merge can never smuggle an unearned song onto the hearth.
  String hearthTrack;
  // v0.67.0 The Dyed Delver — per-delver worn dye (delver id → dye id).
  // Same contract as charEpithet: an absent key falls back to the legacy
  // global activeDye, which is never written after v0.67.0. OWNERSHIP stays
  // global (ownedDyes) — embers buy a dye once and every delver may wear it;
  // only the wearing is per-delver.
  Map<String, String> charDye;
  // v0.115.0 The Delver's Window: the vista a given delver runs under —
  // their own binding when they have one, else the legacy global selection.
  // Same contract as charDye: absent key = default.
  Map<String, String> charVista;

  /// v0.138.0 The Delver's Dice: die skin worn PER DELVER, same shape as
  /// charVista. activeDieSkin survives as the fallback for delvers the
  /// player has not dressed (and for the ledger shelf's global choice).
  Map<String, String> charSkin;
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
  // v0.125.0 The Tempered Hand: faces tempered across the lifetime — banked
  // at run end from the run's own tempers_used (wins AND losses; the forge
  // work was real either way). Monotonic; cloud merge MAX.
  int tempersSet;
  // v0.112.0 The Frostvein: weeklies WON on a doubled week. Monotonic — a
  // derived gate that could re-lock froze hearthgold once (v0.100.0); a
  // counter that only climbs can never take a vista back.
  int doubledWins;
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
  // v0.38.0 The Provings — ids of curated challenge delves cleared.
  Set<String> provingsCleared;
  // v0.127.0 The Full Rotation: canonical rule labels this profile has WON
  // a Weekly under (sorted '+'-joined ids). Union on merge; never shrinks.
  Set<String> weeklyRulesWon;

  /// v0.133.0 The Six Marks: every rune ever tempered onto a face, banked
  /// at run end win or lose (forge work counts like tempersSet). Junk-proof
  /// at the reader: only ids in faceRunes are ever counted.
  Set<String> runesTempered;
  int bestFloor; // deepest 1-based layer ever reached, won or lost
  // v0.65.0 The Charted Depth: the same fact as bestFloor, charted per
  // delver — deepest 1-based layer this character ever stood on, won or
  // lost. Banked in GameController._bankRun beside bestFloor; older saves
  // seed it from runHistory (provable, never invented). Cloud merge:
  // per-key MAX, same convention as charRuns/charWins.
  Map<String, int> charBestFloor;
  int dailiesPlayed; // Daily Delves FINISHED (abandoning counts for nothing)
  int winsNoRest; // runs won without visiting a single rest node
  int hardWins; // runs won on hard
  // v0.96.0 The Hearth Tale: rest-fire hollows left, lifetime. Indexes
  // the fixed tale sequence in lib/data/tales.dart. Monotonic, MAX-merged.
  int hearthTalesHeard;
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
  // v0.33.0 Gramophone: music tracks heard in play (keys of
  // AudioService.musicPaths). 'title_menu' is seeded on load — every profile
  // has heard the hearth. Cloud merge: union, like every other collection.
  Set<String> heardTracks;

  /// v0.79.0 The Settled Score: foe ids whose score has been settled — the
  /// player felled the reigning old foe. Once per foe, ever; never reopened.
  Set<String> settledFoes;
  // In-app review prompt (see lib/meta/review_service.dart): true once the
  // Play review flow has been REQUESTED on this profile. One ask, ever —
  // version bumps never reset it. Cloud merge: sticky OR, so a profile that
  // was already asked on one device is never asked again on another.
  bool reviewAsked;
  // Offline unlock codes (lib/meta/unlock_codes.dart): nonces of codes this
  // profile has redeemed. Re-entering a code is idempotent; cloud merge is
  // a union so a redeem is never forgotten across devices.
  Set<String> redeemedCodes;
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
    this.preferShortRoad = false,
    Map<String, int>? charRuns,
    Map<String, int>? charWins,
    Map<String, int>? charHardWins,
    this.lifetimeEmbers = 0,
    this.exactKills = 0,
    this.exactStreak = 0,
    this.bestExactStreak = 0,
    Set<String>? ownedThemes,
    this.activeTheme = defaultTheme,
    this.hearthTrack = '',
    Set<String>? ownedDieSkins,
    this.activeDieSkin = defaultDieSkin,
    Set<String>? ownedDyes,
    this.activeDye = defaultDye,
    this.selectedVista = defaultVista,
    this.selectedEpithet = defaultEpithet,
    Map<String, String>? charEpithet,
    Map<String, String>? charName,
    Map<String, String>? charDye,
    Map<String, String>? charVista,
    Map<String, String>? charSkin,
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
    this.tempersSet = 0,
    this.doubledWins = 0,
    List<Map<String, Object?>>? runHistory,
    this.forgeUnlocked = false,
    Set<String>? bossesBeaten,
    Set<String>? seenAchievements,
    Set<String>? provingsCleared,
    Set<String>? weeklyRulesWon,
    Set<String>? runesTempered,
    this.bestFloor = 0,
    Map<String, int>? charBestFloor,
    this.dailiesPlayed = 0,
    this.winsNoRest = 0,
    this.hardWins = 0,
    this.hearthTalesHeard = 0,
    Map<String, int>? enemyMet,
    Map<String, int>? enemyFelled,
    Map<String, int>? enemyFellTo,
    this.lastSeenNewsVersion = '',
    Set<String>? heardTracks,
    Set<String>? settledFoes,
    this.reviewAsked = false,
    Set<String>? redeemedCodes,
  }) : runHistory = runHistory ?? [],
       redeemedCodes = redeemedCodes ?? {},
       bossesBeaten = bossesBeaten ?? {},
       seenAchievements = seenAchievements ?? {},
       provingsCleared = provingsCleared ?? {},
       weeklyRulesWon = weeklyRulesWon ?? {},
       runesTempered = runesTempered ?? {},
       unlockedCharacters = unlocked ?? {defaultCharacter},
       charRuns = charRuns ?? {},
       charWins = charWins ?? {},
       charHardWins = charHardWins ?? {},
       charBestFloor = charBestFloor ?? {},
       charEpithet = charEpithet ?? {},
       charName = charName ?? {},
       charDye = charDye ?? {},
       charVista = charVista ?? {},
       charSkin = charSkin ?? {},
       ownedThemes = ownedThemes ?? {defaultTheme},
       ownedDieSkins = ownedDieSkins ?? {defaultDieSkin},
       ownedDyes = ownedDyes ?? {defaultDye},
       ownedCodex = ownedCodex ?? {},
       tipsSeen = tipsSeen ?? {},
       enemyMet = enemyMet ?? {},
       enemyFelled = enemyFelled ?? {},
       enemyFellTo = enemyFellTo ?? {},
       heardTracks = heardTracks ?? {},
       settledFoes = settledFoes ?? {};

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
    if (preferShortRoad) 'preferShortRoad': true,
    'charRuns': charRuns,
    'charWins': charWins,
    if (charHardWins.isNotEmpty) 'charHardWins': charHardWins,
    'lifetimeEmbers': lifetimeEmbers,
    'exactKills': exactKills,
    'exactStreak': exactStreak,
    'bestExactStreak': bestExactStreak,
    'ownedThemes': ownedThemes.toList(),
    'activeTheme': activeTheme,
    'ownedDieSkins': ownedDieSkins.toList(),
    'activeDieSkin': activeDieSkin,
    // Omitted at defaults so pre-wardrobe saves stay byte-identical.
    if (ownedDyes.length > 1) 'ownedDyes': ownedDyes.toList(),
    if (activeDye != defaultDye) 'activeDye': activeDye,
    if (selectedVista != defaultVista) 'selectedVista': selectedVista,
    if (selectedEpithet != defaultEpithet) 'selectedEpithet': selectedEpithet,
    if (charEpithet.isNotEmpty) 'charEpithet': charEpithet,
    if (charName.isNotEmpty) 'charName': charName,
    if (hearthTrack.isNotEmpty) 'hearthTrack': hearthTrack,
    if (charDye.isNotEmpty) 'charDye': charDye,
    if (charVista.isNotEmpty) 'charVista': charVista,
    if (charSkin.isNotEmpty) 'charSkin': charSkin,
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
    if (tempersSet > 0) 'tempersSet': tempersSet,
    if (doubledWins > 0) 'doubledWins': doubledWins,
    if (runHistory.isNotEmpty) 'runHistory': runHistory,
    if (forgeUnlocked) 'forgeUnlocked': true,
    if (bossesBeaten.isNotEmpty) 'bossesBeaten': bossesBeaten.toList(),
    if (seenAchievements.isNotEmpty)
      'seenAchievements': seenAchievements.toList(),
    if (provingsCleared.isNotEmpty) 'provingsCleared': provingsCleared.toList(),
    if (weeklyRulesWon.isNotEmpty) 'weeklyRulesWon': weeklyRulesWon.toList(),
    if (runesTempered.isNotEmpty) 'runesTempered': runesTempered.toList(),
    if (bestFloor > 0) 'bestFloor': bestFloor,
    if (charBestFloor.isNotEmpty) 'charBestFloor': charBestFloor,
    if (dailiesPlayed > 0) 'dailiesPlayed': dailiesPlayed,
    if (winsNoRest > 0) 'winsNoRest': winsNoRest,
    if (hardWins > 0) 'hardWins': hardWins,
    if (hearthTalesHeard > 0) 'hearthTalesHeard': hearthTalesHeard,
    if (enemyMet.isNotEmpty) 'enemyMet': enemyMet,
    if (enemyFelled.isNotEmpty) 'enemyFelled': enemyFelled,
    if (enemyFellTo.isNotEmpty) 'enemyFellTo': enemyFellTo,
    if (lastSeenNewsVersion.isNotEmpty)
      'lastSeenNewsVersion': lastSeenNewsVersion,
    if (heardTracks.isNotEmpty) 'heardTracks': (heardTracks.toList()..sort()),
    if (settledFoes.isNotEmpty) 'settledFoes': (settledFoes.toList()..sort()),
    if (reviewAsked) 'reviewAsked': true,
    if (redeemedCodes.isNotEmpty)
      'redeemedCodes': (redeemedCodes.toList()..sort()),
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

  /// v0.66.0: the title a given delver wears — their own choice when they
  /// have one, else the legacy global selection. EVERY read surface
  /// (picker, summary, share card, run-record banking) goes through this.
  String epithetFor(String charId) => charEpithet[charId] ?? selectedEpithet;

  /// v0.72.0: the name a given delver answers to — the player's gift when
  /// one was given, else the roster name. EVERY surface that speaks OF a
  /// delver (picker, summary, ledger, card banking) goes through this.
  String nameFor(String charId) =>
      charName[charId] ?? characters[charId]?.name ?? charId;

  /// Pure name hygiene: trim, collapse inner whitespace, strip control
  /// characters, clamp to 16 chars. Empty result means "no name given".
  static String sanitizeGivenName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 16 ? cleaned.substring(0, 16).trim() : cleaned;
  }

  static Map<String, String> _nameMap(Object? v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (val is String && characters.containsKey('$k')) {
        final name = sanitizeGivenName(val);
        if (name.isNotEmpty) out['$k'] = name;
      }
    });
    return out;
  }

  /// v0.67.0: the dye a given delver wears — their own choice when they
  /// have one, else the legacy global selection. EVERY sprite-painting
  /// surface (stage, map, picker, hearth, swatches) goes through this.
  String dyeFor(String charId) => charDye[charId] ?? activeDye;

  /// v0.115.0: the vista a given delver runs under — their own binding when
  /// they have one, else the legacy global selection. Every vista-painting
  /// surface with a delver in hand (map grade/wash, cards) goes through
  /// this; delver-less surfaces keep reading [selectedVista].
  String vistaFor(String charId) => charVista[charId] ?? selectedVista;
  String skinFor(String charId) => charSkin[charId] ?? activeDieSkin;

  /// v0.138.0: charSkin's loader — same junk filter, skin catalog.
  static Map<String, String> _skinMap(Object? v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (val is String &&
          characters.containsKey('$k') &&
          dieSkins.containsKey(val)) {
        out['$k'] = val;
      }
    });
    return out;
  }

  static Map<String, String> _vistaMap(Object? v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (val is String &&
          characters.containsKey('$k') &&
          vistas.containsKey(val)) {
        out['$k'] = val;
      }
    });
    return out;
  }

  static Map<String, String> _dyeMap(Object? v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (val is String &&
          characters.containsKey('$k') &&
          delverDyes.containsKey(val)) {
        out['$k'] = val;
      }
    });
    return out;
  }

  static Map<String, String> _epithetMap(Object? v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (val is String &&
          characters.containsKey('$k') &&
          epithets.containsKey(val)) {
        out['$k'] = val;
      }
    });
    return out;
  }

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
    preferShortRoad: j['preferShortRoad'] as bool? ?? false,
    charRuns: _intMap(j['charRuns']),
    charWins: _intMap(j['charWins']),
    charHardWins: _intMap(j['charHardWins']),
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
    ownedDyes:
        ((j['ownedDyes'] as List?)?.cast<String>().toSet()?..add(defaultDye)) ??
        {defaultDye},
    selectedVista: vistas.containsKey(j['selectedVista'])
        ? j['selectedVista'] as String
        : defaultVista,
    selectedEpithet: epithets.containsKey(j['selectedEpithet'])
        ? j['selectedEpithet'] as String
        : defaultEpithet,
    // v0.66.0: unknown delver ids and unknown epithet ids are dropped on
    // decode (same hygiene as the selection fallbacks above).
    charEpithet: _epithetMap(j['charEpithet']),
    charName: _nameMap(j['charName']),
    hearthTrack: j['hearthTrack'] as String? ?? '',
    charDye: _dyeMap(j['charDye']),
    charVista: _vistaMap(j['charVista']),
    charSkin: _skinMap(j['charSkin']),
    activeDye: delverDyes.containsKey(j['activeDye'])
        ? j['activeDye'] as String
        : defaultDye,
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
    tempersSet: j['tempersSet'] as int? ?? 0,
    doubledWins: j['doubledWins'] as int? ?? 0,
    runHistory: ((j['runHistory'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => r.map((k, v) => MapEntry('$k', v as Object?)))
        .toList(),
    forgeUnlocked: j['forgeUnlocked'] as bool? ?? false,
    bossesBeaten: ((j['bossesBeaten'] as List?)?.cast<String>().toSet()) ?? {},
    seenAchievements:
        ((j['seenAchievements'] as List?)?.cast<String>().toSet()) ?? {},
    provingsCleared:
        ((j['provingsCleared'] as List?)?.cast<String>().toSet()) ?? {},
    weeklyRulesWon:
        ((j['weeklyRulesWon'] as List?)?.cast<String>().toSet()) ?? {},
    runesTempered:
        ((j['runesTempered'] as List?)?.cast<String>().toSet()) ?? {},
    // Pre-v0.5.0 saves have no bestFloor. Seeding it from the run history
    // (the deepest floor we can actually prove) is honest; inventing a
    // number from runsPlayed would not be.
    bestFloor:
        j['bestFloor'] as int? ??
        _deepestFloorIn((j['runHistory'] as List?) ?? const []),
    // v0.65.0: pre-charted saves seed the per-delver depths from the run
    // history — the deepest floor we can actually PROVE per character
    // (same honesty rule as bestFloor above).
    charBestFloor: j['charBestFloor'] != null
        ? _intMap(j['charBestFloor'])
        : _charDeepestIn((j['runHistory'] as List?) ?? const []),
    dailiesPlayed:
        j['dailiesPlayed'] as int? ??
        // A pre-v0.5.0 profile with a recorded daily has provably finished
        // at least one; anything beyond that is unknowable, so claim one.
        ((j['lastDailyDate'] is String) ? 1 : 0),
    winsNoRest: j['winsNoRest'] as int? ?? 0,
    hardWins: j['hardWins'] as int? ?? 0,
    hearthTalesHeard: j['hearthTalesHeard'] as int? ?? 0,
    enemyMet: _intMap(j['enemyMet']),
    enemyFelled: _intMap(j['enemyFelled']),
    enemyFellTo: _intMap(j['enemyFellTo']),
    lastSeenNewsVersion: j['lastSeenNewsVersion'] as String? ?? '',
    heardTracks: ((j['heardTracks'] as List?)?.cast<String>().toSet()) ?? {},
    settledFoes: ((j['settledFoes'] as List?)?.cast<String>().toSet()) ?? {},
    reviewAsked: j['reviewAsked'] as bool? ?? false,
    redeemedCodes:
        ((j['redeemedCodes'] as List?)?.cast<String>().toSet()) ?? {},
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

  // v0.65.0 The Charted Depth: per-character deepest floor provable from
  // the run history (used only to seed charBestFloor on pre-v0.65.0 saves).
  static Map<String, int> _charDeepestIn(List raw) {
    final out = <String, int>{};
    for (final r in raw) {
      if (r is! Map) continue;
      final ch = r['character'];
      final f = r['floor'];
      if (ch is! String || f is! int) continue;
      if (f > (out[ch] ?? 0)) out[ch] = f;
    }
    return out;
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

  /// Try to buy a delver dye with embers; returns true on success.
  bool tryBuyDye(String id) {
    final d = delverDyes[id];
    if (d == null || ownedDyes.contains(id)) return false;
    if (embers < d.costEmbers) return false;
    embers -= d.costEmbers;
    ownedDyes.add(id);
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

/// v0.78.0 The Old Foe (moved here in v0.79.0 — the controller needs it): the enemy that has ended more of the player's
/// delves than any other, read from [MetaState.enemyFellTo]. Named flatly —
/// the Ledger states, never goads. Two falls make a foe (one is bad luck);
/// unknown ids (retired content) are skipped rather than crashed on; ties
/// resolve to enemies authoring order so the answer never flickers.
({String id, int falls})? oldFoe(MetaState m) {
  String? bestId;
  var best = 0;
  for (final id in enemiesOrder) {
    final n = m.enemyFellTo[id] ?? 0;
    if (n > best) {
      best = n;
      bestId = id;
    }
  }
  if (bestId == null || best < 2) return null;
  return (id: bestId, falls: best);
}
