// test/kept_hearth_test.dart — v0.140.0 The Kept Hearth.
//
// Two new hearth colours (the anvil and the runes, on the title fire) and
// the honesty fix the re-pricing audit caught: Hearth Keeper said 'own
// every hearth colour' but flipped at 4 — the shelf has sold 12 since
// v0.4.3. Promise wording moves with the catalog, pinned here.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hearth keeper asks for the whole live shelf, junk-proof', () {
    expect(
      achievements['hearth_keeper']!.target,
      hearthThemesOrder.length,
      reason: "promise wording ('every') tracks the live catalog",
    );
    final m = MetaState();
    m.ownedThemes.addAll(hearthThemesOrder);
    m.ownedThemes.add('ghost_colour'); // junk can never stand in
    expect(statValue(m, 'themes_owned', null), hearthThemesOrder.length);
    expect(earnedAchievements(m), contains('hearth_keeper'));
    m.ownedThemes.remove('runefire');
    expect(earnedAchievements(m), isNot(contains('hearth_keeper')));
  });

  test('the new colours sit at the ladder top with real prices', () {
    expect(hearthThemesOrder.sublist(12, 14), ['anvilglow', 'runefire']);
    final prices = [
      for (final id in hearthThemesOrder) hearthThemes[id]!.costEmbers,
    ];
    // Historical ladder has one tie (frostfire/witchlight, both 60 since
    // v0.3.3) — shipped prices never re-price, so the guard is
    // non-descending overall and strictly above the old top for the new.
    for (var i = 1; i < prices.length; i++) {
      expect(
        prices[i] >= prices[i - 1],
        isTrue,
        reason: 'ladder must never descend at index $i',
      );
    }
    expect(hearthThemes['anvilglow']!.costEmbers, 440);
    expect(hearthThemes['runefire']!.costEmbers, 480);
    for (final id in ['anvilglow', 'runefire']) {
      final def = hearthThemes[id]!;
      expect(
        def.warmArgb != def.brightArgb,
        isTrue,
        reason: 'a real gradient, not a flat tint',
      );
      expect(def.text.trim(), isNotEmpty);
    }
  });

  test('the new colours buy through the one existing path', () {
    final c = GameController();
    c.meta.embers = 500;
    expect(c.buyTheme('anvilglow'), isTrue);
    expect(c.meta.embers, 60);
    expect(c.buyTheme('runefire'), isFalse, reason: 'broke refuses');
    expect(c.meta.ownedThemes, contains('anvilglow'));
  });

  test('theme copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    for (final id in ['anvilglow', 'runefire']) {
      final t = hearthThemes[id]!.text.toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
