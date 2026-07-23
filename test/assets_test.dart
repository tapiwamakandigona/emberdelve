// test/assets_test.dart — asset integrity for the assets-integration work:
// sprite_meta.json parses and every sheet it references is bundled; every
// SFX/music id the audio service references is bundled; backgrounds, icon
// mappings, and the in-app CREDITS.md are all present.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> expectAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
    } catch (e) {
      fail('missing bundled asset: $path ($e)');
    }
  }

  test('sprite_meta.json parses and every referenced sheet asset exists',
      () async {
    final meta = SpriteMeta.parse(
        await rootBundle.loadString('assets/images/sprite_meta.json'));

    // Every game enemy and character has a sheet; no orphan meta entries.
    for (final id in enemiesOrder) {
      expect(meta.enemies.containsKey(id), isTrue,
          reason: 'enemy $id has no sprite_meta entry');
    }
    for (final id in charactersOrder) {
      expect(meta.characters.containsKey(id), isTrue,
          reason: 'character $id has no sprite_meta entry');
    }

    for (final def in [...meta.enemies.values, ...meta.characters.values]) {
      expect(def.frameW, greaterThan(0));
      expect(def.frameH, greaterThan(0));
      expect(def.fps, greaterThan(0));
      expect(def.rows.containsKey('idle'), isTrue,
          reason: '${def.id} has no idle row');
      for (final row in def.rows.values) {
        expect(row.frames, greaterThanOrEqualTo(1));
        expect(row.row, greaterThanOrEqualTo(0));
      }
      await expectAsset(def.assetPath);
    }
  });

  test('every SFX and music id the audio service references exists',
      () async {
    for (final path in AudioService.sfxPaths.values) {
      await expectAsset('assets/$path');
    }
    for (final path in AudioService.musicPaths.values) {
      await expectAsset('assets/$path');
    }
    // Event-mapped SFX ids must all be real SFX ids.
    for (final id in AudioService.eventSfx.values) {
      expect(AudioService.sfxPaths.containsKey(id), isTrue,
          reason: 'eventSfx maps to unknown sfx id $id');
    }
  });

  test('backgrounds, icon mappings, and credits are bundled', () async {
    for (final bg in [Art.bgTitle, Art.bgMap, Art.bgCombat, Art.bgBoss]) {
      await expectAsset(bg);
    }
    for (final asset in Art.nodeIcons.values) {
      await expectAsset(asset);
    }
    for (final id in relicsOrder) {
      await expectAsset(Art.relicIcon(id));
    }
    for (final id in eventsOrder) {
      await expectAsset(Art.eventIcon(id));
    }
    for (final size in [4, 6, 8, 10, 12]) {
      await expectAsset(Art.dieIcon(size));
    }
    await expectAsset(Art.currencyCoin);
    await expectAsset(Art.currencyEmber);
    await expectAsset(Art.currencyInsight);

    // CC-BY attribution must ship in-app: the bundled credits file.
    final credits = await rootBundle.loadString('CREDITS.md');
    expect(credits, contains('CC BY'));
    expect(credits, contains('Kevin MacLeod'));
    expect(credits, contains('game-icons.net'));
  });
}
