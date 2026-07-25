import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/catalog.dart';
import 'package:emberdelve/meta/economy.dart';

void main() {
  group('Wallet', () {
    test('earn and spend', () {
      final w = Wallet(coins: 100);
      expect(w.spend(Currency.coins, 40), isTrue);
      expect(w.coins, 60);
      expect(w.spend(Currency.coins, 61), isFalse);
      expect(w.coins, 60, reason: 'failed spend must not change balance');
      w.earn(Currency.feathers, 5);
      expect(w.feathers, 5);
    });

    test('json round-trip', () {
      final w = Wallet(coins: 12, feathers: 3);
      final back = Wallet.fromJson(w.toJson());
      expect(back.coins, 12);
      expect(back.feathers, 3);
    });
  });

  group('buy', () {
    test('happy path deducts and owns', () {
      final w = Wallet(coins: 500);
      final owned = <String>{'squire_blade'};
      final r = buy(
          wallet: w,
          currency: Currency.coins,
          price: 450,
          id: 'woodsman_axe',
          owned: owned,
          ownedAbilities: {});
      expect(r, PurchaseResult.ok);
      expect(w.coins, 50);
      expect(owned, contains('woodsman_axe'));
    });

    test('rejects double-buy and poverty', () {
      final w = Wallet(coins: 10);
      final owned = <String>{'squire_blade'};
      expect(
          buy(
              wallet: w,
              currency: Currency.coins,
              price: 0,
              id: 'squire_blade',
              owned: owned,
              ownedAbilities: {}),
          PurchaseResult.alreadyOwned);
      expect(
          buy(
              wallet: w,
              currency: Currency.coins,
              price: 450,
              id: 'woodsman_axe',
              owned: owned,
              ownedAbilities: {}),
          PurchaseResult.cantAfford);
      expect(w.coins, 10);
    });

    test('haggler discounts coin prices only', () {
      expect(
          effectivePrice(
              currency: Currency.coins, price: 1000, ownedAbilities: {'haggler'}),
          900);
      expect(
          effectivePrice(
              currency: Currency.feathers, price: 12, ownedAbilities: {'haggler'}),
          12);
    });
  });

  group('catalog integrity', () {
    test('unique ids across all categories', () {
      final ids = [
        ...kWeapons.map((w) => w.id),
        ...kSkins.map((s) => s.id),
        ...kAbilities.map((a) => a.id),
        ...kSpells.map((s) => s.id),
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('exactly one free starter weapon and skin', () {
      expect(kWeapons.where((w) => w.price == 0).length, 1);
      expect(kSkins.where((s) => s.price == 0).length, 1);
      // Spells are deliberately premium-only (AKP-4d): the slot is a pure
      // economy sink like AK's magic. No free starter spell, ever.
      expect(kSpells.where((s) => s.price == 0), isEmpty);
    });

    test('stats sane', () {
      for (final w in kWeapons) {
        expect(w.damage, inInclusiveRange(1, 20));
        expect(w.critPercent, inInclusiveRange(0, 50));
        expect(w.critMultiplier, greaterThanOrEqualTo(1.0));
        expect(w.price, greaterThanOrEqualTo(0));
      }
    });

    test('skin power curve gentle and capped', () {
      final s = skinById('red');
      expect(s.powerAt(1), 1.0);
      expect(s.powerAt(Skin.maxLevel), lessThanOrEqualTo(1.3));
      expect(Skin.killsForLevel(2), greaterThan(Skin.killsForLevel(1)));
    });
  });
}
