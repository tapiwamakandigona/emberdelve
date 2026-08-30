// test/delvers_dice_test.dart — v0.138.0 The Delver's Dice.
//
// Die skins worn PER DELVER (the charVista shape, third application):
// charSkin preference map, activeDieSkin surviving as the fallback and
// the ledger shelf's global choice, activeRunSkin feeding every in-run
// DieChip. Preference maps merge fresh-copy, never _maxMap (v0.123 rule).
import 'package:emberdelve/data/skins.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skinFor falls back to the global choice until dressed', () {
    final m = MetaState()..activeDieSkin = 'obsidian';
    expect(m.skinFor('kindler'), 'obsidian');
    m.charSkin['kindler'] = 'tempered';
    expect(m.skinFor('kindler'), 'tempered');
    expect(m.skinFor('warden'), 'obsidian', reason: 'others keep the global');
  });

  test('setSkinFor gates on ownership and unlocked delver', () {
    final c = GameController();
    c.meta.unlockedCharacters.add('warden');
    c.setSkinFor('tempered', forChar: 'warden');
    expect(c.meta.charSkin['warden'], isNull, reason: 'unowned skin refused');
    c.meta.ownedDieSkins.add('tempered');
    c.setSkinFor('tempered', forChar: 'gambler');
    expect(c.meta.charSkin['gambler'], isNull, reason: 'locked delver refused');
    c.setSkinFor('tempered', forChar: 'warden');
    expect(c.meta.charSkin['warden'], 'tempered');
    c.setSkinFor(defaultDieSkin, forChar: 'warden');
    expect(
      c.meta.charSkin['warden'],
      defaultDieSkin,
      reason: 'the default is always wearable',
    );
  });

  test('activeRunSkin reads the run delver, else the global', () {
    final c = GameController();
    c.meta.activeDieSkin = 'obsidian';
    c.meta.charSkin['kindler'] = 'runeglass';
    expect(c.activeRunSkin, 'obsidian', reason: 'no run live');
    c.startRun(character: 'kindler', seed: 5, boons: false);
    expect(c.activeRunSkin, 'runeglass');
  });

  test('charSkin survives persistence; merge is fresh-copy preference', () {
    final m = MetaState()..charSkin['kindler'] = 'tempered';
    final back = MetaState.fromJson(m.toJson());
    expect(back.charSkin['kindler'], 'tempered');
    final cloud = MetaState()..charSkin['kindler'] = 'obsidian';
    final merged = mergeMetaStates(back, cloud);
    expect(
      merged.charSkin['kindler'],
      isNotNull,
      reason: 'preference survives the merge',
    );
  });
}
