// test/deep_hearth_test.dart — v0.157.0 The Deep Hearth.
//
// Two hearth colours join the shelf: Twiceflame (the Deep Mark's magenta,
// tempered a shade deeper) and Marshlight (a chartreuse the shelf never
// held). Same charter as every cosmetic: real prices up front, no gameplay
// effect, no pressure copy. Hearth Keeper's 'every colour' promise moves
// with the live catalog (the v0.140.0 honesty rule).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the new colours sit at the ladder top with real prices', () {
    expect(hearthThemesOrder.length, 16);
    expect(hearthThemesOrder.sublist(14), ['twiceflame', 'marshlight']);
    expect(hearthThemes['twiceflame']!.costEmbers, 520);
    expect(hearthThemes['marshlight']!.costEmbers, 560);
    final prices = [
      for (final id in hearthThemesOrder) hearthThemes[id]!.costEmbers,
    ];
    for (var i = 1; i < prices.length; i++) {
      expect(
        prices[i] >= prices[i - 1],
        isTrue,
        reason: 'ladder must never descend at index $i',
      );
    }
    for (final id in ['twiceflame', 'marshlight']) {
      final def = hearthThemes[id]!;
      expect(
        def.warmArgb != def.brightArgb,
        isTrue,
        reason: 'a real gradient, not a flat tint',
      );
      expect(def.text.trim(), isNotEmpty);
    }
  });

  test("hearth keeper's 'every colour' promise moved with the shelf", () {
    expect(
      achievements['hearth_keeper']!.target,
      hearthThemesOrder.length,
      reason: "promise wording ('every') tracks the live catalog",
    );
    final m = MetaState();
    m.ownedThemes.addAll(hearthThemesOrder);
    expect(earnedAchievements(m), contains('hearth_keeper'));
    m.ownedThemes.remove('marshlight');
    expect(earnedAchievements(m), isNot(contains('hearth_keeper')));
  });

  test('the new colours buy through the one existing path', () {
    final c = GameController();
    c.meta.embers = 600;
    expect(c.buyTheme('twiceflame'), isTrue);
    expect(c.meta.embers, 80);
    expect(c.buyTheme('marshlight'), isFalse, reason: 'broke refuses');
    expect(c.meta.ownedThemes, contains('twiceflame'));
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
    for (final id in ['twiceflame', 'marshlight']) {
      final t = hearthThemes[id]!.text.toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
