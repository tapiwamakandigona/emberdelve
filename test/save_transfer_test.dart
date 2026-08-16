// test/save_transfer_test.dart — the Carried Ember (v0.24.0) codec contract:
// round-trip fidelity, tamper rejection, whitespace tolerance, the paid
// unlock never travelling in the code, and import-merge non-destruction.
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/save_transfer.dart';

/// A deliberately full-fat state: every counter set, every set populated,
/// history at cap — the worst honest case a real save can be.
MetaState fullFat({bool forge = true}) {
  return MetaState(
    embers: 412,
    unlocked: {'kindler', 'warden', 'gambler', 'ascetic'},
    bestAscension: 13,
    runsPlayed: 187,
    runsWon: 96,
    tutorialSeen: true,
    tipsSeen: {'first_map', 'first_shop', 'first_rest'},
    preferredDifficulty: 'hard',
    difficultyChosen: true,
    charRuns: {'kindler': 80, 'warden': 41, 'gambler': 40, 'ascetic': 26},
    charWins: {'kindler': 44, 'warden': 20, 'gambler': 19, 'ascetic': 13},
    lifetimeEmbers: 9034,
    exactKills: 61,
    exactStreak: 2,
    bestExactStreak: 7,
    ownedThemes: {'emberglow', 'verdigris', 'violet'},
    activeTheme: 'verdigris',
    ownedDieSkins: {'bone', 'obsidian'},
    activeDieSkin: 'obsidian',
    ownedCodex: {'enemy:ash_wretch', 'relic:siege_hook'},
    lastDailyDate: '2026-08-15',
    lastDailyWon: true,
    lastDailyFloor: 9,
    lastDailyFloors: 9,
    lastWeeklyKey: 'Week of 2026-08-10',
    lastWeeklyWon: false,
    lastWeeklyFloor: 6,
    lastWeeklyFloors: 9,
    lastWeeklyMutator: 'brittle_dice',
    weekliesPlayed: 11,
    runHistory: [
      for (var i = 0; i < MetaState.runHistoryCap; i++)
        {
          'date': '2026-08-${(i % 28) + 1}'.padLeft(10, '0'),
          'character': 'kindler',
          'difficulty': 'hard',
          'ascension': i % 14,
          'result': i.isEven ? 'won' : 'lost',
          'floor': (i % 9) + 1,
          'floors': 9,
          'seed': 1000000 + i,
          'embers': 40 + i,
          if (i == 0) 'daily': true,
        },
    ],
    forgeUnlocked: forge,
    bossesBeaten: {'ashen_colossus', 'ember_tyrant', 'hearthless_king'},
    seenAchievements: {'first_ember', 'boss_slayer'},
    bestFloor: 9,
    dailiesPlayed: 23,
    winsNoRest: 4,
    hardWins: 18,
    enemyMet: {'ash_wretch': 150, 'coal_seam_wyrm': 9},
    enemyFelled: {'ash_wretch': 140, 'coal_seam_wyrm': 7},
    enemyFellTo: {'ash_wretch': 10, 'coal_seam_wyrm': 2},
    lastSeenNewsVersion: '0.23.0',
  );
}

void main() {
  test('round-trip preserves every field except the paid unlock', () {
    final src = fullFat(forge: true);
    final out = decodeSaveCode(encodeSaveCode(src));
    expect(out, isNotNull);
    final a = src.toJson()..remove('forgeUnlocked');
    final b = out!.toJson();
    expect(out.forgeUnlocked, isFalse,
        reason: 'the purchase must not travel in a pasteable code');
    expect(jsonEncode(b), jsonEncode(a),
        reason: 'everything else survives byte-for-byte');
  });

  test('encode is deterministic for the same state', () {
    expect(encodeSaveCode(fullFat()), encodeSaveCode(fullFat()));
  });

  test('whitespace and line wraps in a paste are tolerated', () {
    final code = encodeSaveCode(fullFat());
    final mangled = code
        .replaceRange(20, 20, '\n')
        .replaceRange(60, 60, '  ')
        .replaceRange(100, 100, '\r\n');
    expect(decodeSaveCode(' $mangled \n'), isNotNull);
  });

  test('tampered, truncated, and garbage codes all decode to null', () {
    final code = encodeSaveCode(fullFat());
    // Flip one payload character (avoid the dots and the prefix).
    final i = code.indexOf('.') + 5;
    final flipped = code.replaceRange(
        i, i + 1, code[i] == 'A' ? 'B' : 'A');
    expect(decodeSaveCode(flipped), isNull, reason: 'checksum catches a flip');
    expect(decodeSaveCode(code.substring(0, code.length - 3)), isNull,
        reason: 'truncation');
    expect(decodeSaveCode('EMBER9${code.substring(6)}'), isNull,
        reason: 'unknown prefix');
    expect(decodeSaveCode(''), isNull);
    expect(decodeSaveCode('not a save code at all'), isNull);
    expect(decodeSaveCode('EMBER1.aGVsbG8.deadbeefdeadbeef'), isNull,
        reason: 'valid-shaped but wrong checksum/payload');
  });

  test('a hand-built code carrying forgeUnlocked still cannot grant it', () {
    // An attacker pastes a code whose json DOES claim the unlock. The
    // decoder strips the field before fromJson ever sees it.
    final j = fullFat(forge: true).toJson(); // includes forgeUnlocked: true
    final payload = gzip.encode(utf8.encode(jsonEncode(j)));
    final code = '$saveCodePrefix.${base64UrlEncode(payload)}'
        '.${fnv1a64Hex(payload)}';
    final out = decodeSaveCode(code);
    expect(out, isNotNull);
    expect(out!.forgeUnlocked, isFalse);
  });

  test('import merge never revokes a local unlock or loses local progress',
      () {
    // Local: fresher, forge owned. Imported: an OLD export from before.
    final local = fullFat(forge: true);
    final imported = decodeSaveCode(encodeSaveCode(MetaState(
      embers: 10,
      runsPlayed: 5,
      runsWon: 1,
      lifetimeEmbers: 50,
      unlocked: {'kindler', 'ember_witch_old'},
    )))!;
    final merged = mergeMetaStates(local, imported);
    expect(merged.forgeUnlocked, isTrue, reason: 'OR — never revoked');
    expect(merged.embers, local.embers, reason: 'fresher side spendables');
    expect(merged.runsPlayed, local.runsPlayed, reason: 'MAX counters');
    expect(merged.lifetimeEmbers, local.lifetimeEmbers);
    expect(merged.unlockedCharacters,
        containsAll({...local.unlockedCharacters, 'ember_witch_old'}),
        reason: 'UNION — earned anywhere stays earned');
    expect(merged.runHistory, local.runHistory,
        reason: 'fresher side history kept wholesale');
  });

  test('a full-fat code stays clipboard-small (< 4 KB)', () {
    expect(encodeSaveCode(fullFat()).length, lessThan(4096));
  });

  test('summary states the facts of the code', () {
    final s = saveCodeSummary(fullFat());
    expect(s, contains('187 delves'));
    expect(s, contains('96 won'));
    expect(s, contains('9034 embers banked'));
    expect(s, contains('4 delvers'));
  });
}
