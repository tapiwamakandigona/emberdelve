import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/meta/progress_state.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ember_save_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('fresh save has starter loadout', () async {
    final store = SaveStore(baseDirOverride: tmp);
    final s = await store.load();
    expect(s.coins, 0);
    expect(s.ownedWeapons, {'squire_blade'});
    expect(s.equippedSkin, 'red');
  });

  test('round-trip preserves everything', () async {
    final store = SaveStore(baseDirOverride: tmp);
    final s = SaveData(coins: 123, feathers: 4)
      ..ownedWeapons.add('ember_fang')
      ..equippedWeapon = 'ember_fang'
      ..skinKills['red'] = 77
      ..tutorialSeen = true;
    s.recordFor('w1_l1')
      ..finished = true
      ..allChests = true
      ..chestsOpened = 3
      ..bestTimeMs = 61250;
    await store.save(s);

    final back = await store.load();
    expect(back.coins, 123);
    expect(back.feathers, 4);
    expect(back.equippedWeapon, 'ember_fang');
    expect(back.skinKills['red'], 77);
    expect(back.tutorialSeen, isTrue);
    final rec = back.levels['w1_l1']!;
    expect(rec.finished, isTrue);
    expect(rec.medals, 2);
    expect(rec.bestTimeMs, 61250);
  });

  test('corrupt live file falls back to backup', () async {
    final store = SaveStore(baseDirOverride: tmp);
    await store.save(SaveData(coins: 50));
    await store.save(SaveData(coins: 99)); // 50-coin save becomes .bak
    final live = File('${tmp.path}/emberdelve_save.json');
    live.writeAsStringSync('{corrupt!!!');
    final back = await store.load();
    expect(back.coins, 50, reason: 'backup should win over corrupt live file');
  });

  test('legacy v1 dice save migrates to fresh save + bonus', () async {
    final live = File('${tmp.path}/emberdelve_save.json');
    live.writeAsStringSync(jsonEncode({
      'version': 1,
      'embers': 900,
      'unlockedCharacters': ['ascetic'],
    }));
    final store = SaveStore(baseDirOverride: tmp);
    final s = await store.load();
    expect(s.legacyBonusGranted, isTrue);
    expect(s.coins, 250);
    expect(s.ownedWeapons, {'squire_blade'});
  });

  group('progression rules', () {
    test('levels unlock sequentially, boss needs all', () {
      final s = SaveData();
      expect(isLevelUnlocked(s, 0), isTrue);
      expect(isLevelUnlocked(s, 1), isFalse);
      s.recordFor('w1_l1').finished = true;
      expect(isLevelUnlocked(s, 1), isTrue);
      expect(isLevelUnlocked(s, 5), isFalse, reason: 'boss locked');
      for (final e in kWorld1.where((e) => !e.isBoss)) {
        s.recordFor(e.id).finished = true;
      }
      expect(isLevelUnlocked(s, 5), isTrue);
    });

    test('skin levels from kills; melee power grows', () {
      final s = SaveData();
      expect(skinLevel(s, 'red'), 1);
      s.skinKills['red'] = 25; // killsForLevel(1)
      expect(skinLevel(s, 'red'), 2);
      expect(meleePower(s), closeTo(1.03, 1e-9));
    });

    test('warden blade grants a heart; apple pouch grows capacity', () {
      final s = SaveData();
      expect(maxHearts(s), 3);
      s.equippedWeapon = 'warden_blade';
      expect(maxHearts(s), 4);
      expect(appleCapacity(s), 10);
      s.ownedAbilities.add('apple_pouch');
      expect(appleCapacity(s), 13);
    });
  });
}
